extends GdUnitTestSuite
## Integration test confirming Main actually reads previously-saved parent
## settings -- card count (and its matching grid shape) and enabled
## categories -- on startup through the real scene tree. The other half of
## those features; parent_settings_test.gd covers that ParentSettings can
## write them, this covers that main.gd applies them. Each test sets its
## own Settings value(s) before creating its own scene_runner (rather than
## a shared before_test()) since the value has to be in place *before*
## Main._ready() runs. Redirects Settings to a scratch file for the whole
## suite (see [method Settings.use_path_for_testing]) so a developer's real
## user://settings.cfg is never touched, regardless of persist=true/false
## discipline in any one test.

const SCRATCH_PATH := "user://test_settings.cfg"

var runner: GdUnitSceneRunner


func before() -> void:
	Settings.use_path_for_testing(SCRATCH_PATH)


func after() -> void:
	Settings.use_path_for_testing(Settings.DEFAULT_PATH)
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")


func after_test() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT, false)
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, WordDatabase.get_all_categories(), false)
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


func test_main_applies_stored_enabled_categories_on_startup() -> void:
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, ["animals", "vehicles"], false)
	runner = scene_runner("res://scenes/main.tscn")
	await runner.await_input_processed()
	var main := runner.scene() as Main

	assert_that(main.enabled_categories).contains_exactly_in_any_order(["animals", "vehicles"])
	for word: Dictionary in main.displayed_words:
		var in_animals: bool = word.image.contains("/assets/images/animals/")
		var in_vehicles: bool = word.image.contains("/assets/images/vehicles/")
		assert_that(in_animals or in_vehicles).is_true()


func test_main_falls_back_to_no_filter_for_too_few_stored_categories() -> void:
	# Below WordDatabase.MIN_ENABLED_CATEGORIES -- the settings screen itself
	# would never save this, but stored data could still end up this way.
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, ["animals"], false)
	runner = scene_runner("res://scenes/main.tscn")
	await runner.await_input_processed()
	var main := runner.scene() as Main

	assert_that(main.enabled_categories).is_empty() # no filter -- every category
