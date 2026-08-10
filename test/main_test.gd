extends GdUnitTestSuite
## Unit tests for main.gd's pure-logic helpers -- grid math and target
## picking -- that don't touch the scene tree, timers, or audio, so they run
## instantly without a scene_runner. See main_integration_test.gd for the
## full round flow through the real scene.


func test_slot_offset_first_cell_is_grid_origin() -> void:
	var main: Main = auto_free(Main.new())
	main.columns = 4
	assert_that(main._slot_offset(0, Vector2(100, 100), 10.0, 20.0)).is_equal(Vector2.ZERO)


func test_slot_offset_wraps_to_next_row() -> void:
	var main: Main = auto_free(Main.new())
	main.columns = 4
	# Index 5 with 4 columns -> column 1, row 1.
	var offset := main._slot_offset(5, Vector2(100, 100), 10.0, 20.0)
	assert_that(offset).is_equal(Vector2(110.0, 120.0))


func test_pick_target_word_avoids_immediate_repeat() -> void:
	var main: Main = auto_free(Main.new())
	main.displayed_words = [
		{"key": "WORD_A", "image": "res://a.svg"},
		{"key": "WORD_B", "image": "res://b.svg"},
	]
	main.last_target_key = "WORD_A"

	for i in 20: # shuffle-backed pick: run enough times to catch flakes
		var word: Dictionary = main.pick_target_word()
		assert_that(word.key).is_equal("WORD_B")


func test_pick_target_word_allows_repeat_when_only_one_card() -> void:
	var main: Main = auto_free(Main.new())
	main.displayed_words = [{"key": "WORD_A", "image": "res://a.svg"}]
	main.last_target_key = "WORD_A"

	var word: Dictionary = main.pick_target_word()
	assert_that(word.key).is_equal("WORD_A")


func test_pick_target_word_with_no_previous_target_can_return_any() -> void:
	var main: Main = auto_free(Main.new())
	main.displayed_words = [
		{"key": "WORD_A", "image": "res://a.svg"},
		{"key": "WORD_B", "image": "res://b.svg"},
	]
	main.last_target_key = ""

	var word: Dictionary = main.pick_target_word()
	assert_that(["WORD_A", "WORD_B"]).contains(word.key)
