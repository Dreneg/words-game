extends Node
## Autoload `Settings`: generic local key/value store for parent-gated
## settings, backed by [ConfigFile] at [member settings_path].
##
## Persistence here is best-effort, not mission-critical: any load/save
## failure (missing file on first run, a corrupt file, web/HTML5 `user://`
## quirks) is logged and swallowed rather than crashing -- callers just get
## their supplied fallback default. To add a new setting: call
## [method get_value]/[method set_value] with a new key from wherever its
## control lives in `scenes/parent/parent_settings.tscn`. No other code
## changes are needed. See docs/parent-mode.md.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"

## Overridable so tests can redirect persistence to a scratch file (see
## [method use_path_for_testing]) instead of a developer's real save data.
## Some tests exercise genuine production code paths -- e.g. simulating a
## button tap through ParentSettings -- that call [method set_value] with
## its default persist=true, which would otherwise write to
## [constant DEFAULT_PATH] for real on every test run.
var settings_path: String = DEFAULT_PATH

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	_load()


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
	var err := _config.save(settings_path)
	if err != OK:
		push_warning("Settings: failed to save %s (error %d); changes may not persist." % [settings_path, err])


## Test-only: points this store at [param path] (a scratch file -- never
## pass [constant DEFAULT_PATH] here) and discards in-memory state, so
## tests never inherit -- or overwrite -- whatever's genuinely saved on the
## machine running them. Call from a suite's before(); restore with
## [code]use_path_for_testing(DEFAULT_PATH)[/code] in after() so a later
## suite isn't left pointed at a scratch file that no longer exists.
func use_path_for_testing(path: String) -> void:
	settings_path = path
	_config = ConfigFile.new()
	_load()


func _load() -> void:
	var err := _config.load(settings_path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: failed to load %s (error %d); starting with defaults." % [settings_path, err])
