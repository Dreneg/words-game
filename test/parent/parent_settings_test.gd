extends GdUnitTestSuite
## Tests for ParentSettings (scripts/parent/parent_settings.gd): the settings
## screen reached after ParentGate accepts the code. Card-count tests use
## persist=false and always restore BoardLayout.DEFAULT_COUNT afterward so
## they don't leave the shared [autoload Settings] instance polluted for
## other tests/suites in the same run.

const ParentSettingsScene := preload("res://scenes/parent/parent_settings.tscn")


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
