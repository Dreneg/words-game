extends GdUnitTestSuite
## Tests for [autoload Settings] (scripts/settings.gd): the generic local
## key/value store behind the parent settings screen. Uses persist=false
## throughout so these don't write to a developer's real user://settings.cfg.


func test_missing_key_returns_supplied_default() -> void:
	assert_that(Settings.get_value("__test_missing_key__", "fallback")).is_equal("fallback")


func test_set_value_then_get_value_round_trips() -> void:
	Settings.set_value("__test_round_trip__", 42, false)
	assert_that(Settings.get_value("__test_round_trip__", null)).is_equal(42)
