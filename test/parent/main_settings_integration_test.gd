extends GdUnitTestSuite
## Integration test confirming Main actually reads a previously-saved
## card-count setting -- and derives the matching grid shape from it -- on
## startup through the real scene tree. The other half of the "parent picks
## a card count" feature; parent_settings_test.gd covers that ParentSettings
## can write one, this covers that main.gd applies it (count and columns
## both). Each test sets its own Settings value before creating its own
## scene_runner (rather than a shared before_test()) since the value has to
## be in place *before* Main._ready() runs.

var runner: GdUnitSceneRunner


func after_test() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT, false)
	# GdUnitSceneRunner is RefCounted, not a Node -- it can't be .free()'d
	# manually. Dropping the reference triggers its own NOTIFICATION_PREDELETE
	# cleanup (removes and frees the instantiated scene) immediately.
	runner = null


func test_main_applies_stored_card_count_and_matching_columns_on_startup() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, 9, false)
	runner = scene_runner("res://scenes/main.tscn")
	await runner.await_input_processed()
	var main := runner.scene() as Main

	assert_that(main.image_count).is_equal(9)
	assert_that(main.columns).is_equal(3) # 9 cards -> a 3x3 board
	assert_that(main.card_grid.columns).is_equal(3)
	assert_that(main.card_grid.get_child_count()).is_equal(9)


func test_main_falls_back_to_default_for_a_malformed_stored_value() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, "not-a-number", false)
	runner = scene_runner("res://scenes/main.tscn")
	await runner.await_input_processed()
	var main := runner.scene() as Main

	assert_that(main.image_count).is_equal(BoardLayout.DEFAULT_COUNT)
	assert_that(main.columns).is_equal(4) # 12 cards -> a 3x4 board
