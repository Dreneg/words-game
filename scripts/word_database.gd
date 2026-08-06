extends Node
## Autoload singleton exposing the master word list: each entry pairs a
## localization key (see localization/words.csv) with its placeholder icon.
##
## To add a new word: add a row to localization/words.csv, drop the icon
## under assets/images/<category>/, drop audio under
## assets/audio/<locale>/<KEY>.ogg, then add one entry below. No other code
## changes needed.

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
]


## Returns up to [param count] distinct word entries ({"key", "image"}),
## chosen at random. Clamped to the size of [constant WORDS] if [param count]
## asks for more words than exist.
func get_random_words(count: int) -> Array[Dictionary]:
	var pool := WORDS.duplicate()
	pool.shuffle()
	count = clampi(count, 0, pool.size())
	var result: Array[Dictionary] = []
	for i in count:
		result.append(pool[i])
	return result


## Resolves the spoken-word audio file for [param key] in [param locale]
## (defaults to the active locale), falling back to the project's fallback
## locale (see project.godot) if that locale has no recording yet.
func get_audio_path(key: String, locale: String = "") -> String:
	if locale.is_empty():
		locale = TranslationServer.get_locale()
	locale = locale.substr(0, 2)
	var path := "res://assets/audio/%s/%s.ogg" % [locale, key]
	if ResourceLoader.exists(path):
		return path
	var fallback_locale: String = ProjectSettings.get_setting("internationalization/locale/fallback", "hu")
	return "res://assets/audio/%s/%s.ogg" % [fallback_locale, key]
