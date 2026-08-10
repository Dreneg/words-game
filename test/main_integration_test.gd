extends GdUnitTestSuite
## Integration tests for the core match-the-word game loop, driven through
## scene_runner against the real main.tscn (real WordCard instances, real
## timers, real WordDatabase autoload) rather than mocking pieces out.
##
## These tests wait out main.gd's actual delay_before_prompt timer in real
## time (scene_runner shares the same SceneTree that get_tree().create_timer()
## schedules against, so there's no fast-forward without changing production
## code) -- keep the number of full-round tests here small since each one
## costs ~2 real seconds.
##
## Not covered here: reroll_board() (the animated board-swap after
## correct_answers_per_reroll correct answers) and the retry_delay
## re-prompt loop -- both are tween/timer-heavy, slow to exercise for real,
## and low-risk relative to the core prompt/tap/advance loop tested below.

var runner: GdUnitSceneRunner


func before_test() -> void:
	runner = scene_runner("res://scenes/main.tscn")


func after_test() -> void:
	# GdUnitSceneRunner is RefCounted, not a Node -- it can't be .free()'d
	# manually. Dropping the reference triggers its own NOTIFICATION_PREDELETE
	# cleanup (removes and frees the instantiated scene) immediately.
	runner = null


func test_spawns_board_with_configured_card_count() -> void:
	await runner.await_input_processed()
	var main := runner.scene() as Main

	assert_that(main.card_grid.get_child_count()).is_equal(main.image_count)
	assert_that(main.round_active).is_false()


func test_correct_tap_advances_round_and_disables_card() -> void:
	var main := await _await_first_prompt()

	var target_key := main.current_target_key
	var target_card := _find_card(main, target_key)

	target_card.icon_button.pressed.emit()

	assert_that(main.round_active).is_false()
	assert_that(main.correct_count).is_equal(1)
	assert_that(main.last_target_key).is_equal(target_key)
	assert_that(target_card.disabled).is_true()


func test_wrong_tap_is_ignored() -> void:
	var main := await _await_first_prompt()

	var wrong_card := _find_card_other_than(main, main.current_target_key)

	wrong_card.icon_button.pressed.emit()

	assert_that(main.round_active).is_true()
	assert_that(main.correct_count).is_equal(0)
	assert_that(wrong_card.disabled).is_false()


## Waits out [member Main.delay_before_prompt] so the first word has been
## spoken and a round is active, then returns the scene's Main instance.
func _await_first_prompt() -> Main:
	await runner.await_input_processed()
	var main := runner.scene() as Main
	await runner.simulate_frames(1, int(main.delay_before_prompt * 1000.0) + 200)
	assert_that(main.round_active).is_true()
	assert_that(main.current_target_key).is_not_empty()
	return main


func _find_card(main: Main, word_key: String) -> WordCard:
	for child in main.card_grid.get_children():
		var card := child as WordCard
		if card and card.word_key == word_key:
			return card
	return null


func _find_card_other_than(main: Main, word_key: String) -> WordCard:
	for child in main.card_grid.get_children():
		var card := child as WordCard
		if card and card.word_key != word_key:
			return card
	return null
