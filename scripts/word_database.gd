extends Node
## Autoload singleton exposing the master word list: each entry pairs a
## localization key (see localization/words.csv) with its placeholder icon.
## A word's category (for the parent settings "enabled categories" list --
## see [method get_all_categories]) is derived from the icon's folder, not
## stored separately -- there is deliberately only one place that says which
## category a word belongs to.
##
## To add a new word: add a row to localization/words.csv, drop the icon
## under assets/images/<category>/, drop audio under
## assets/audio/<locale>/<KEY>.ogg, then add one entry below. No other code
## changes needed. To add a new *category*: same steps, plus a
## CATEGORY_<NAME> row in localization/ui.csv for its settings-screen label
## (see docs/parent-mode.md) -- everything else (the settings checkbox list,
## word filtering) picks it up automatically.

const WORDS: Array[Dictionary] = [
	{"key": "WORD_DOG", "image": "res://assets/images/animals/dog.svg"},
	{"key": "WORD_CAT", "image": "res://assets/images/animals/cat.svg"},
	{"key": "WORD_COW", "image": "res://assets/images/animals/cow.svg"},
	{"key": "WORD_FISH", "image": "res://assets/images/animals/fish.svg"},
	{"key": "WORD_BIRD", "image": "res://assets/images/animals/bird.svg"},
	{"key": "WORD_DUCK", "image": "res://assets/images/animals/duck.svg"},
	{"key": "WORD_HORSE", "image": "res://assets/images/animals/horse.svg"},
	{"key": "WORD_SHEEP", "image": "res://assets/images/animals/sheep.svg"},
	{"key": "WORD_PIG", "image": "res://assets/images/animals/pig.svg"},
	{"key": "WORD_RABBIT", "image": "res://assets/images/animals/rabbit.svg"},
	{"key": "WORD_APPLE", "image": "res://assets/images/food/apple.svg"},
	{"key": "WORD_WATERMELON", "image": "res://assets/images/food/watermelon.svg"},
	{"key": "WORD_BREAD", "image": "res://assets/images/food/bread.svg"},
	{"key": "WORD_EGG", "image": "res://assets/images/food/egg.svg"},
	{"key": "WORD_CARROT", "image": "res://assets/images/food/carrot.svg"},
	{"key": "WORD_SUN", "image": "res://assets/images/nature/sun.svg"},
	{"key": "WORD_FLOWER", "image": "res://assets/images/nature/flower.svg"},
	{"key": "WORD_MOON", "image": "res://assets/images/nature/moon.svg"},
	{"key": "WORD_CLOUD", "image": "res://assets/images/nature/cloud.svg"},
	{"key": "WORD_BALL", "image": "res://assets/images/objects/ball.svg"},
	{"key": "WORD_CAR", "image": "res://assets/images/objects/car.svg"},
	{"key": "WORD_HOUSE", "image": "res://assets/images/objects/house.svg"},
	{"key": "WORD_SHOE", "image": "res://assets/images/objects/shoe.svg"},
	{"key": "WORD_BOOK", "image": "res://assets/images/objects/book.svg"},
	{"key": "WORD_CUP", "image": "res://assets/images/objects/cup.svg"},
	{"key": "WORD_COLOR_RED", "image": "res://assets/images/colors/red.svg"},
	{"key": "WORD_COLOR_BLUE", "image": "res://assets/images/colors/blue.svg"},
	{"key": "WORD_COLOR_GREEN", "image": "res://assets/images/colors/green.svg"},
	{"key": "WORD_COLOR_YELLOW", "image": "res://assets/images/colors/yellow.svg"},
	{"key": "WORD_COLOR_ORANGE", "image": "res://assets/images/colors/orange.svg"},
	{"key": "WORD_COLOR_PINK", "image": "res://assets/images/colors/pink.svg"},
	{"key": "WORD_COLOR_PURPLE", "image": "res://assets/images/colors/purple.svg"},
	{"key": "WORD_COLOR_BROWN", "image": "res://assets/images/colors/brown.svg"},
	{"key": "WORD_COLOR_BLACK", "image": "res://assets/images/colors/black.svg"},
	{"key": "WORD_COLOR_WHITE", "image": "res://assets/images/colors/white.svg"},
	{"key": "WORD_PLANE", "image": "res://assets/images/vehicles/plane.svg"},
	{"key": "WORD_BOAT", "image": "res://assets/images/vehicles/boat.svg"},
	{"key": "WORD_TRAIN", "image": "res://assets/images/vehicles/train.svg"},
	{"key": "WORD_BUS", "image": "res://assets/images/vehicles/bus.svg"},
	{"key": "WORD_DUMP_TRUCK", "image": "res://assets/images/vehicles/dump_truck.svg"},
	{"key": "WORD_TRACTOR", "image": "res://assets/images/vehicles/tractor.svg"},
	{"key": "WORD_EXCAVATOR", "image": "res://assets/images/vehicles/excavator.svg"},
	{"key": "WORD_BICYCLE", "image": "res://assets/images/vehicles/bicycle.svg"},
	{"key": "WORD_MOTORCYCLE", "image": "res://assets/images/vehicles/motorcycle.svg"},
	{"key": "WORD_FIRE_TRUCK", "image": "res://assets/images/vehicles/fire_truck.svg"},
]

## Short positive-feedback sounds ("well done!", ...) played when the player
## taps the correct card. Kept in their own assets/audio/<locale>/praise/
## folder and key namespace so they never get mixed up with the playable
## words above. Add a new one by dropping a ~0.5-1.5s clip there and adding
## its key here.
const PRAISE_KEYS: Array[String] = [
	"PRAISE_WELL_DONE",
	"PRAISE_GREAT",
	"PRAISE_THATS_IT",
	"PRAISE_AWESOME",
]

## Fewest categories the parent settings screen will ever let stay enabled
## at once, and the floor [method Main._apply_stored_enabled_categories]
## re-validates a stored value against -- below this there may not be
## enough distinct words left for a board. See docs/parent-mode.md.
const MIN_ENABLED_CATEGORIES := 2


## Returns up to [param count] distinct word entries ({"key", "image"}),
## chosen at random from [param categories] (see [method get_all_categories]),
## or every category if [param categories] is empty/omitted. Clamped to the
## size of the filtered pool if [param count] asks for more words than exist.
func get_random_words(count: int, categories: Array[String] = []) -> Array[Dictionary]:
	var pool := WORDS.duplicate()
	if not categories.is_empty():
		pool = pool.filter(func(word: Dictionary) -> bool: return categories.has(_category_for_word(word)))
	pool.shuffle()
	count = clampi(count, 0, pool.size())
	var result: Array[Dictionary] = []
	for i in count:
		result.append(pool[i])
	return result


## Every distinct category name, derived from [constant WORDS]'s image
## paths (the folder under assets/images/) rather than hand-listed anywhere
## -- adding a new category is just dropping words into a new
## assets/images/<category>/ folder and a matching CATEGORY_<NAME> entry in
## localization/ui.csv; this list (and therefore the parent settings
## screen's checkbox list) picks it up automatically. Order is first-seen
## in [constant WORDS], not alphabetical, but stable.
func get_all_categories() -> Array[String]:
	var seen: Dictionary = {}
	var categories: Array[String] = []
	for word: Dictionary in WORDS:
		var category := _category_for_word(word)
		if not seen.has(category):
			seen[category] = true
			categories.append(category)
	return categories


func _category_for_word(word: Dictionary) -> String:
	return (word.image as String).get_base_dir().get_file()


## Resolves the spoken-word audio file for [param key] in [param locale]
## (defaults to the active locale), falling back to the project's fallback
## locale (see project.godot) if that locale has no recording yet.
func get_audio_path(key: String, locale: String = "") -> String:
	return _resolve_audio_path("res://assets/audio/%s/%s.ogg", key, locale)


## Picks one random positive-feedback sound (see [constant PRAISE_KEYS]) and
## resolves it for [param locale] the same way [method get_audio_path] does.
func get_random_praise_path(locale: String = "") -> String:
	var key: String = PRAISE_KEYS.pick_random()
	return _resolve_audio_path("res://assets/audio/%s/praise/%s.ogg", key, locale)


func _resolve_audio_path(path_template: String, key: String, locale: String) -> String:
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	locale = locale.substr(0, 2)
	var path := path_template % [locale, key]
	if ResourceLoader.exists(path):
		return path
	var fallback_locale: String = ProjectSettings.get_setting("internationalization/locale/fallback", "hu")
	return path_template % [fallback_locale, key]
