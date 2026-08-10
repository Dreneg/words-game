extends GdUnitTestSuite
## Tests for WordCard (scripts/word_card.gd): the tappable icon card used on
## the game board. Instantiated from the real word_card.tscn scene since
## icon_button is resolved via a %Icon unique-name lookup in _ready(), which
## only runs once the card is actually added to the tree.

const WordCardScene := preload("res://scenes/word_card.tscn")


func test_setup_assigns_key_and_icon() -> void:
	var card := auto_free(WordCardScene.instantiate()) as WordCard
	add_child(card)

	card.setup("WORD_DOG", "res://assets/images/animals/dog.svg")

	assert_that(card.word_key).is_equal("WORD_DOG")
	assert_that(card.icon_button.texture_normal).is_not_null()


func test_disabled_forwards_to_icon_button() -> void:
	var card := auto_free(WordCardScene.instantiate()) as WordCard
	add_child(card)

	assert_that(card.icon_button.disabled).is_false()
	card.disabled = true
	assert_that(card.icon_button.disabled).is_true()
	card.disabled = false
	assert_that(card.icon_button.disabled).is_false()


func test_tap_emits_selected_with_word_key() -> void:
	var card := auto_free(WordCardScene.instantiate()) as WordCard
	add_child(card)
	card.setup("WORD_CAT", "res://assets/images/animals/cat.svg")

	# Monitoring must start before the tap: pressed.emit() dispatches its
	# connected callables (and therefore "selected") synchronously, so a
	# monitor attached afterwards would miss it.
	monitor_signals(card)
	card.icon_button.pressed.emit()

	await assert_signal(card).is_emitted("selected", ["WORD_CAT"])


func test_play_correct_feedback_disables_card() -> void:
	var card := auto_free(WordCardScene.instantiate()) as WordCard
	add_child(card)

	card.play_correct_feedback()

	assert_that(card.disabled).is_true()
	assert_that(card.icon_button.disabled).is_true()
