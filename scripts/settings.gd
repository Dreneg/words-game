extends Node
## Autoload `Settings`: generic local key/value store for parent-gated
## settings, backed by [ConfigFile] at [constant SETTINGS_PATH].
##
## Persistence here is best-effort, not mission-critical: any load/save
## failure (missing file on first run, a corrupt file, web/HTML5 `user://`
## quirks) is logged and swallowed rather than crashing -- callers just get
## their supplied fallback default. To add a new setting: call
## [method get_value]/[method set_value] with a new key from wherever its
## control lives in `scenes/parent/parent_settings.tscn`. No other code
## changes are needed. See docs/parent-mode.md.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: failed to load %s (error %d); starting with defaults." % [SETTINGS_PATH, err])


func get_value(key: String, default: Variant = null) -> Variant:
	return _config.get_value(SECTION, key, default)


## Sets [param key] to [param value] and, unless [param persist] is false,
## immediately writes the whole store to disk. [param persist] exists as an
## escape hatch for a future batch-editing UI; the default write-through
## behavior is the simplest mental model for a single setting change.
func set_value(key: String, value: Variant, persist: bool = true) -> void:
	_config.set_value(SECTION, key, value)
	if persist:
		save()


func save() -> void:
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Settings: failed to save %s (error %d); changes may not persist." % [SETTINGS_PATH, err])
