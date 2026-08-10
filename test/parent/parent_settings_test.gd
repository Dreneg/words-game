extends GdUnitTestSuite
## Tests for ParentSettings (scripts/parent/parent_settings.gd): the settings
## screen reached after ParentGate accepts the code. Redirects Settings to a
## scratch file for the whole suite (see [method Settings.use_path_for_testing])
## -- several tests here tap real buttons/checkboxes, which go through
## ParentSettings' actual production signal handlers and therefore call
## Settings.set_value() with its default persist=true; without the
## redirect that would write to a developer's real user://settings.cfg on
## every test run. Individual tests still restore shared keys to their
## defaults afterward (persist=false is enough for that, since it's the
## same scratch file for the rest of the suite either way) so they don't
## leave state for the *next* test in this file.

const ParentSettingsScene := preload("res://scenes/parent/parent_settings.tscn")
const SCRATCH_PATH := "user://test_settings.cfg"


func before() -> void:
	Settings.use_path_for_testing(SCRATCH_PATH)


func after() -> void:
	Settings.use_path_for_testing(Settings.DEFAULT_PATH)
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")


func test_close_button_emits_closed() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	monitor_signals(settings)
	settings.close_button.pressed.emit()

	await assert_signal(settings).is_emitted("closed")


func test_card_count_buttons_are_labeled_by_their_actual_board_shape() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	# Not the bare card count -- the RxC shape it actually lays out as.
	assert_that(_find_card_count_button(settings, 9).text).is_equal("3x3")
	assert_that(_find_card_count_button(settings, 12).text).is_equal("3x4")
	assert_that(_find_card_count_button(settings, 15).text).is_equal("3x5")


func test_card_count_row_marks_the_stored_value_pressed() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, 15, false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	assert_that(_find_card_count_button(settings, 9).button_pressed).is_false()
	assert_that(_find_card_count_button(settings, 12).button_pressed).is_false()
	assert_that(_find_card_count_button(settings, 15).button_pressed).is_true()

	Settings.set_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT, false)


func test_card_count_row_defaults_to_twelve_when_nothing_stored() -> void:
	Settings.set_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT, false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	assert_that(_find_card_count_button(settings, 12).button_pressed).is_true()


func test_tapping_a_card_count_option_saves_it() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	_find_card_count_button(settings, 9).pressed.emit()

	assert_that(Settings.get_value(SettingsKeys.CARD_COUNT, -1)).is_equal(9)
	Settings.set_value(SettingsKeys.CARD_COUNT, BoardLayout.DEFAULT_COUNT, false)


func test_category_list_has_one_checkbox_per_category() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	assert_that(settings.category_list.get_child_count()).is_equal(WordDatabase.get_all_categories().size())
	assert_that(_find_category_checkbox(settings, "animals")).is_not_null()


func test_category_checkboxes_default_to_all_enabled_when_nothing_stored() -> void:
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, WordDatabase.get_all_categories(), false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	for category in WordDatabase.get_all_categories():
		assert_that(_find_category_checkbox(settings, category).button_pressed).is_true()


## Unlike the other category tests, which reuse this suite's shared scratch
## file (which by the time most of them run already has *some* value
## written to it by an earlier test, even if it happens to match the real
## default), this redirects to a guaranteed-nonexistent file so the key is
## truly absent -- an actual first launch, not just "was reset to the
## default value".
func test_category_checkboxes_default_to_all_enabled_on_a_genuinely_fresh_install() -> void:
	var dir := DirAccess.open("user://")
	var fresh_filename := "test_settings_fresh_install.cfg"
	if dir and dir.file_exists(fresh_filename):
		dir.remove(fresh_filename)
	Settings.use_path_for_testing("user://" + fresh_filename)

	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	for category in WordDatabase.get_all_categories():
		assert_that(_find_category_checkbox(settings, category).button_pressed).is_true()

	Settings.use_path_for_testing(SCRATCH_PATH)
	if dir and dir.file_exists(fresh_filename):
		dir.remove(fresh_filename)


func test_category_checkboxes_reflect_a_stored_subset() -> void:
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, ["animals", "vehicles"], false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	assert_that(_find_category_checkbox(settings, "animals").button_pressed).is_true()
	assert_that(_find_category_checkbox(settings, "vehicles").button_pressed).is_true()
	assert_that(_find_category_checkbox(settings, "food").button_pressed).is_false()

	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, WordDatabase.get_all_categories(), false)


func test_toggling_a_category_checkbox_saves_it() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	# _on_category_toggled re-reads every checkbox's actual button_pressed
	# state (not the emitted argument), so that has to be set first --
	# same as a real click would leave it.
	var colors := _find_category_checkbox(settings, "colors")
	colors.button_pressed = false
	colors.toggled.emit(false)

	var enabled: Array = Settings.get_value(SettingsKeys.ENABLED_CATEGORIES, [])
	assert_that(enabled.has("colors")).is_false()

	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, WordDatabase.get_all_categories(), false)


## The core "at least 2" rule: once unchecking would drop below the
## minimum, the still-checked boxes lock (disable) rather than allowing a
## drop below it -- see [method ParentSettings._update_category_lock_state].
func test_unchecking_down_to_the_minimum_locks_the_remaining_checked_boxes() -> void:
	var all_categories := WordDatabase.get_all_categories()
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, all_categories, false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	# Uncheck every category but the first two.
	for category in all_categories.slice(2):
		var checkbox := _find_category_checkbox(settings, category)
		checkbox.button_pressed = false
		checkbox.toggled.emit(false)

	var first := _find_category_checkbox(settings, all_categories[0])
	var second := _find_category_checkbox(settings, all_categories[1])
	assert_that(first.button_pressed).is_true()
	assert_that(second.button_pressed).is_true()
	assert_that(first.disabled).is_true()
	assert_that(second.disabled).is_true()

	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, all_categories, false)


func test_checking_a_third_category_unlocks_the_locked_ones() -> void:
	var all_categories := WordDatabase.get_all_categories()
	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, all_categories.slice(0, 2), false)
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	var first := _find_category_checkbox(settings, all_categories[0])
	assert_that(first.disabled).is_true() # locked at exactly the minimum

	var third := _find_category_checkbox(settings, all_categories[2])
	third.button_pressed = true
	third.toggled.emit(true)

	assert_that(first.disabled).is_false()

	Settings.set_value(SettingsKeys.ENABLED_CATEGORIES, all_categories, false)


func _find_category_checkbox(settings: ParentSettings, category: String) -> CheckBox:
	for child in settings.category_list.get_children():
		if child.name == category:
			return child as CheckBox
	return null


## Matches by node name (e.g. "CardCount9"), not by displayed text -- the
## text is now the "RxC" label (see [method ParentSettings._setup_card_count_row]),
## which isn't uniquely parseable back to a card count (all three options
## currently start with the same row count).
func _find_card_count_button(settings: ParentSettings, value: int) -> Button:
	for child in settings.card_count_row.get_children():
		var button := child as Button
		if button and button.name.trim_prefix("CardCount").to_int() == value:
			return button
	return null
