class_name Main
extends Control
## Core game loop for the word-matching screen:
## show a board of cards -> wait -> speak a word -> wait for the matching
## tap -> celebrate -> wait -> speak the next word -> ...
##
## The board (assets/images/, localization/words.csv) is populated once per
## session from [autoload WordDatabase]; only the spoken target changes each
## round. See CLAUDE.md for the localization/placeholder asset pipeline.

const WordCardScene := preload("res://scenes/word_card.tscn")

## How many cards are on the board at once. Tune here or in the Inspector
## for the default; the parent-mode settings screen can override this at
## runtime (see [constant SettingsKeys.CARD_COUNT]), read back in [method _ready].
@export var image_count: int = 12
## Columns in the card grid; rows follow automatically. Used as the
## fallback for an [member image_count] outside the parent-configurable
## board sizes (see [BoardLayout]) -- for a count in [constant
## BoardLayout.OPTIONS], [method _ready] overrides this to match that
## option's actual shape (e.g. 9 cards -> 3 columns, a 3x3 board) rather
## than this fixed value.
@export var columns: int = 4
## Pause between showing the board (or a correct answer) and speaking the
## next word, in seconds.
@export var delay_before_prompt: float = 2.0
## Pause after a correct tap before the next word is spoken, in seconds.
@export var delay_after_correct: float = 2.0
## If nobody's tapped the right card this long after a word was (re-)spoken,
## say it again — they may have missed or forgotten it. Keeps repeating on
## this interval for as long as the round stays unanswered.
@export var retry_delay: float = 5.0
## After this many correct answers, swap in a fresh set of words (see
## [method reroll_board]) instead of just continuing with the same board.
## Set to 0 to never reroll.
@export var correct_answers_per_reroll: int = 8

@onready var card_grid: GridContainer = %CardGrid
@onready var word_audio_player: AudioStreamPlayer = %WordAudioPlayer
@onready var praise_audio_player: AudioStreamPlayer = %PraiseAudioPlayer

## Word categories (see [method WordDatabase.get_all_categories]) the board
## draws from; empty means no filter (every category). Resolved once in
## [method _ready] from the parent-chosen Settings value, same as
## [member image_count]/[member columns] -- see
## [method _apply_stored_enabled_categories].
var enabled_categories: Array[String] = []
var displayed_words: Array[Dictionary] = []
var current_target_key: String = ""
var last_target_key: String = ""
## Correct taps since the last reroll (or since the game started). See
## [member correct_answers_per_reroll].
var correct_count: int = 0
## True only while a word has been spoken and we're waiting for a matching
## tap. Taps are ignored outside this window (e.g. before the first prompt).
var round_active: bool = false


func _ready() -> void:
	_apply_stored_card_count()
	_apply_stored_enabled_categories()
	columns = BoardLayout.columns_for(image_count, columns)
	card_grid.columns = columns
	spawn_board()
	start_round()


## Overrides [member image_count] with the parent-chosen value from
## [autoload Settings], if one was ever saved. Falls back to (and leaves
## untouched) the @export default on first run or if the stored value is
## missing or malformed -- Settings persistence is best-effort, not
## mission-critical, so this must never fail loudly. See docs/parent-mode.md.
func _apply_stored_card_count() -> void:
	var stored: Variant = Settings.get_value(SettingsKeys.CARD_COUNT, image_count)
	if stored is int and stored > 0:
		image_count = stored


## Overrides [member enabled_categories] with the parent-chosen set from
## [autoload Settings], filtered to categories that still actually exist
## and re-checked against [constant WordDatabase.MIN_ENABLED_CATEGORIES] --
## the settings screen itself prevents saving fewer, but this re-validates
## rather than trusting stored data blindly (same reasoning as
## [method _apply_stored_card_count]). Falls back to no filter (every
## category) on first run or if the stored value doesn't hold up.
func _apply_stored_enabled_categories() -> void:
	var all_categories := WordDatabase.get_all_categories()
	var stored: Variant = Settings.get_value(SettingsKeys.ENABLED_CATEGORIES, all_categories)
	var valid: Array[String] = []
	if stored is Array:
		for entry: Variant in stored:
			if entry is String and all_categories.has(entry):
				valid.append(entry)
	# Not a ternary: `valid if ... else []` infers as plain untyped Array,
	# which fails to assign into the typed Array[String] member below.
	if valid.size() >= WordDatabase.MIN_ENABLED_CATEGORIES:
		enabled_categories = valid
	else:
		enabled_categories = []


## Instantiates a fresh set of [member image_count] random, distinct cards.
## Called once at startup; the board stays put for the rest of the session
## while [method start_round] cycles through target words.
func spawn_board() -> void:
	for child in card_grid.get_children():
		child.queue_free()

	displayed_words = WordDatabase.get_random_words(image_count, enabled_categories)
	for word in displayed_words:
		var card := WordCardScene.instantiate() as WordCard
		card_grid.add_child(card)
		card.setup(word.key, word.image)
		card.selected.connect(_on_card_selected)


## Swaps in a fresh random set of [member image_count] words, animating the
## transition: cards whose word survives into the new set slide to their new
## grid slot, cards that drop out pop/spin/fade away, and brand-new cards
## fade in at their slot. Awaits until the whole transition has finished.
func reroll_board() -> void:
	var new_words := WordDatabase.get_random_words(image_count, enabled_categories)
	var new_keys: Dictionary = {}
	for word in new_words:
		new_keys[word.key] = true

	var old_cards_by_key: Dictionary = {}
	for child in card_grid.get_children():
		var card := child as WordCard
		if card:
			old_cards_by_key[card.word_key] = card

	if old_cards_by_key.is_empty():
		displayed_words = new_words
		spawn_board()
		return

	var kept: Array[WordCard] = []
	var removed: Array[WordCard] = []
	for key: String in old_cards_by_key:
		var card: WordCard = old_cards_by_key[key]
		if new_keys.has(key):
			kept.append(card)
		else:
			removed.append(card)

	# Reference frame for the animation: the grid's own position/size right
	# now, and the uniform cell size/gap every card shares. Captured before
	# we touch anything, since removing cards from card_grid would otherwise
	# change its computed layout mid-animation.
	var grid_origin: Vector2 = card_grid.global_position
	var card_size: Vector2 = card_grid.get_child(0).size
	var h_sep: float = card_grid.get_theme_constant("h_separation")
	var v_sep: float = card_grid.get_theme_constant("v_separation")

	var anim_layer := Control.new()
	anim_layer.name = "RerollAnimLayer"
	anim_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anim_layer)

	# Move every current card into the free-form overlay, preserving its
	# exact on-screen spot, so GridContainer's own layout pass can't fight
	# the tween while we animate positions by hand.
	for card in kept + removed:
		var old_pos := card.global_position
		card_grid.remove_child(card)
		anim_layer.add_child(card)
		card.global_position = old_pos

	var tween := create_tween().set_parallel(true)

	for i in new_words.size():
		var key: String = new_words[i].key
		if old_cards_by_key.has(key) and new_keys.has(key):
			var card: WordCard = old_cards_by_key[key]
			var target := grid_origin + _slot_offset(i, card_size, h_sep, v_sep)
			tween.tween_property(card, "global_position", target, 0.5) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	for card in removed:
		var spin: float = deg_to_rad(25.0 if randf() > 0.5 else -25.0)
		tween.tween_property(card, "scale", Vector2(1.7, 1.7), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "rotation", spin, 0.35)
		tween.tween_property(card, "modulate:a", 0.0, 0.35)

	await tween.finished
	for card in removed:
		card.queue_free()

	# Rebuild the final card list in the new board's order -- reusing kept
	# cards, instantiating (invisible, for a fade-in) anything brand new.
	var final_cards: Array[WordCard] = []
	var fade_in_cards: Array[WordCard] = []
	for i in new_words.size():
		var word: Dictionary = new_words[i]
		if old_cards_by_key.has(word.key) and new_keys.has(word.key):
			final_cards.append(old_cards_by_key[word.key])
		else:
			var card := WordCardScene.instantiate() as WordCard
			card.modulate.a = 0.0
			anim_layer.add_child(card) # must precede setup(): it needs %Icon, resolved in _ready()
			card.size = card_size # anim_layer isn't a Container, so this won't resolve on its own
			card.setup(word.key, word.image)
			card.selected.connect(_on_card_selected)
			card.global_position = grid_origin + _slot_offset(i, card_size, h_sep, v_sep)
			final_cards.append(card)
			fade_in_cards.append(card)

	# Reparent into the grid in final order -- it snaps each card to exactly
	# where we already animated it to, so there's no visible jump.
	for card in final_cards:
		anim_layer.remove_child(card)
		card_grid.add_child(card)
		card.scale = Vector2.ONE
		card.rotation = 0.0

	anim_layer.queue_free()
	displayed_words = new_words

	var fade_tween := create_tween().set_parallel(true)
	for card in fade_in_cards:
		fade_tween.tween_property(card, "modulate:a", 1.0, 0.4)
	await fade_tween.finished


## Local offset of grid slot [param index] (0-based, row-major) from the
## grid's own top-left, given the uniform card size and gaps every card in
## it shares. Mirrors GridContainer's own layout math so animated cards line
## up exactly with where the real layout will place them.
func _slot_offset(index: int, card_size: Vector2, h_sep: float, v_sep: float) -> Vector2:
	var col := index % columns
	var row := index / columns
	return Vector2(col * (card_size.x + h_sep), row * (card_size.y + v_sep))


## Waits [member delay_before_prompt], then speaks the next target word.
## process_always=false so this halts while the tree is paused (parent mode)
## instead of speaking a new prompt underneath the gate/settings screen --
## see docs/parent-mode.md.
func start_round() -> void:
	round_active = false
	current_target_key = ""
	_reset_cards()
	await get_tree().create_timer(delay_before_prompt, false).timeout
	play_prompt()


## Re-enables every card. Needed because [method WordCard.play_correct_feedback]
## disables the tapped card, and the board is reused across rounds instead of
## being respawned — without this, a word that comes up again later would be
## stuck un-tappable from its first correct answer.
func _reset_cards() -> void:
	for child in card_grid.get_children():
		var card := child as WordCard
		if card:
			card.disabled = false


func play_prompt() -> void:
	var word := pick_target_word()
	current_target_key = word.key
	round_active = true
	_speak_target()
	_watch_for_no_answer(current_target_key)


func _speak_target() -> void:
	word_audio_player.stream = load(WordDatabase.get_audio_path(current_target_key))
	word_audio_player.play()


## Re-speaks the current target every [member retry_delay] seconds for as
## long as this exact round is still unanswered, in case the player missed
## or forgot the word. Stops on its own once the round ends (a correct tap,
## or a new round starting) since [param target] then no longer matches.
## process_always=false: see [method start_round].
func _watch_for_no_answer(target: String) -> void:
	while round_active and current_target_key == target:
		await get_tree().create_timer(retry_delay, false).timeout
		if round_active and current_target_key == target:
			_speak_target()


## Picks a random word from the current board, avoiding an immediate repeat
## of the last target when there's more than one card to choose from.
func pick_target_word() -> Dictionary:
	var candidates := displayed_words.duplicate()
	if candidates.size() > 1 and not last_target_key.is_empty():
		candidates = candidates.filter(func(w: Dictionary) -> bool: return w.key != last_target_key)
	candidates.shuffle()
	return candidates[0]


func _on_card_selected(word_key: String) -> void:
	if not round_active or word_key != current_target_key:
		return # No active prompt yet, or a wrong tap: do nothing, per design.

	round_active = false
	last_target_key = current_target_key
	correct_count += 1

	for child in card_grid.get_children():
		var card := child as WordCard
		if card and card.word_key == current_target_key:
			card.play_correct_feedback()
			break

	praise_audio_player.stream = load(WordDatabase.get_random_praise_path())
	praise_audio_player.play()

	# process_always=false: see [method start_round].
	await get_tree().create_timer(delay_after_correct, false).timeout

	if correct_answers_per_reroll > 0 and correct_count % correct_answers_per_reroll == 0:
		await reroll_board()

	start_round()
