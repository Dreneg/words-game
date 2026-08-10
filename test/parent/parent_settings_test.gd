extends GdUnitTestSuite
## Tests for ParentSettings (scripts/parent/parent_settings.gd): the (for
## now) empty settings screen reached after ParentGate accepts the code.

const ParentSettingsScene := preload("res://scenes/parent/parent_settings.tscn")


func test_close_button_emits_closed() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	monitor_signals(settings)
	settings.close_button.pressed.emit()

	await assert_signal(settings).is_emitted("closed")


func test_content_container_starts_empty() -> void:
	var settings := auto_free(ParentSettingsScene.instantiate()) as ParentSettings
	add_child(settings)

	# Placeholder today -- future settings controls get added under here.
	assert_that(settings.content_container.get_child_count()).is_equal(0)
