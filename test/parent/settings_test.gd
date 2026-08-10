extends GdUnitTestSuite
## Tests for [autoload Settings] (scripts/settings.gd): the generic local
## key/value store behind the parent settings screen. Redirects Settings to
## a scratch file for the whole suite (see [method Settings.use_path_for_testing])
## so these never touch a developer's real user://settings.cfg -- true even
## for a persist=true round trip, which relying on persist=false discipline
## alone wouldn't cover.

const SCRATCH_PATH := "user://test_settings.cfg"


func before() -> void:
	Settings.use_path_for_testing(SCRATCH_PATH)


func after() -> void:
	Settings.use_path_for_testing(Settings.DEFAULT_PATH)
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_settings.cfg"):
		dir.remove("test_settings.cfg")


func test_missing_key_returns_supplied_default() -> void:
	assert_that(Settings.get_value("__test_missing_key__", "fallback")).is_equal("fallback")


func test_set_value_then_get_value_round_trips() -> void:
	Settings.set_value("__test_round_trip__", 42, false)
	assert_that(Settings.get_value("__test_round_trip__", null)).is_equal(42)


func test_set_value_with_persist_actually_writes_to_disk() -> void:
	Settings.set_value("__test_persisted__", "hello", true)

	# Reload from disk into a separate ConfigFile to confirm this was
	# actually written, not just held in Settings' own in-memory copy.
	var reloaded := ConfigFile.new()
	assert_that(reloaded.load(SCRATCH_PATH)).is_equal(OK)
	assert_that(reloaded.get_value(Settings.SECTION, "__test_persisted__")).is_equal("hello")
