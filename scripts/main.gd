extends Control
## Core game loop for the word-matching screen:
## show a board of cards -> wait -> speak a word -> wait for the matching
## tap -> celebrate -> wait -> speak the next word -> ...
##
## The board (assets/images/, localization/words.csv) is populated once per
## session from [autoload WordDatabase]; only the spoken target changes each
## round. See CLAUDE.md for the localization/placeholder asset pipeline.

const WordCardScene := preload("res://scenes/word_card.tscn")

## How many cards are on the board at once. Tune here or in the Inspector.
@export var image_count: int = 12
## Columns in the card grid; rows follow automatically.
@export var columns: int = 4
## Pause between showing the board (or a correct answer) and speaking the
## next word, in seconds.
@export var delay_before_prompt: float = 2.0
## Pause after a correct tap before the next word is spoken, in seconds.
@export var delay_after_correct: float = 2.0

@onready var card_grid: GridContainer = %CardGrid
@onready var word_audio_player: AudioStreamPlayer = %WordAudioPlayer

var displayed_words: Array[Dictionary] = []
var current_target_key: String = ""
var last_target_key: String = ""
## True only while a word has been spoken and we're waiting for a matching
## tap. Taps are ignored outside this window (e.g. before the first prompt).
var round_active: bool = false


func _ready() -> void:
	card_grid.columns = columns
	spawn_board()
	start_round()


## Instantiates a fresh set of [member image_count] random, distinct cards.
## Called once at startup; the board stays put for the rest of the session
## while [method start_round] cycles through target words.
func spawn_board() -> void:
	for child in card_grid.get_children():
		child.queue_free()

	displayed_words = WordDatabase.get_random_words(image_count)
	for word in displayed_words:
		var card := WordCardScene.instantiate() as WordCard
		card_grid.add_child(card)
		card.setup(word.key, word.image)
		card.selected.connect(_on_card_selected)


## Waits [member delay_before_prompt], then speaks the next target word.
func start_round() -> void:
	round_active = false
	current_target_key = ""
	await get_tree().create_timer(delay_before_prompt).timeout
	play_prompt()


func play_prompt() -> void:
	var word := pick_target_word()
	current_target_key = word.key
	round_active = true
	word_audio_player.stream = load(WordDatabase.get_audio_path(current_target_key))
	word_audio_player.play()


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

	for child in card_grid.get_children():
		var card := child as WordCard
		if card and card.word_key == current_target_key:
			card.play_correct_feedback()
			break

	await get_tree().create_timer(delay_after_correct).timeout
	start_round()
