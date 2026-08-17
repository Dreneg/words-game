extends GdUnitTestSuite
## Tests for [autoload WordDatabase] (scripts/word_database.gd): the random
## word picker and the per-locale audio path resolver, both pure logic that
## doesn't touch the scene tree.

const WORD_COUNT := 61 # Keep in sync with WordDatabase.WORDS.


func test_get_random_words_returns_requested_count() -> void:
	var words := WordDatabase.get_random_words(5)
	assert_that(words).has_size(5)


func test_get_random_words_returns_distinct_entries() -> void:
	var words := WordDatabase.get_random_words(WORD_COUNT)
	var keys: Array[String] = []
	for word: Dictionary in words:
		keys.append(word.key)
	assert_that(keys.size()).is_equal(_unique_count(keys))


func test_get_random_words_clamps_to_pool_size() -> void:
	var words := WordDatabase.get_random_words(WORD_COUNT + 50)
	assert_that(words).has_size(WORD_COUNT)


func test_get_random_words_zero_returns_empty() -> void:
	var words := WordDatabase.get_random_words(0)
	assert_that(words).is_empty()


func test_get_random_words_entry_shape() -> void:
	var words := WordDatabase.get_random_words(1)
	assert_that(words[0].has("key")).is_true()
	assert_that(words[0].has("image")).is_true()
	assert_that(words[0].image).starts_with("res://assets/images/")


func test_get_audio_path_resolves_explicit_locale() -> void:
	var path := WordDatabase.get_audio_path("WORD_DOG", "hu")
	assert_that(path).is_equal("res://assets/audio/hu/WORD_DOG.ogg")


func test_get_audio_path_falls_back_when_locale_missing() -> void:
	# "fr" has no recordings yet, so this must fall back to the project's
	# fallback locale ("hu", per project.godot) rather than a dead path.
	var path := WordDatabase.get_audio_path("WORD_DOG", "fr")
	assert_that(path).is_equal("res://assets/audio/hu/WORD_DOG.ogg")


func test_get_random_praise_path_resolves_to_a_known_key() -> void:
	var path := WordDatabase.get_random_praise_path("hu")
	assert_that(WordDatabase.PRAISE_KEYS.any(func(key: String) -> bool: \
		return path == "res://assets/audio/hu/praise/%s.ogg" % key)).is_true()


func test_get_all_categories_returns_every_distinct_folder() -> void:
	var categories := WordDatabase.get_all_categories()
	# Keep in sync with assets/images/: animals, colors, food, nature,
	# objects, vehicles.
	assert_that(categories).contains_exactly_in_any_order(
		["animals", "colors", "food", "nature", "objects", "vehicles"])


func test_get_all_categories_has_no_duplicates() -> void:
	var categories := WordDatabase.get_all_categories()
	assert_that(categories.size()).is_equal(_unique_count(categories))


func test_get_random_words_filters_to_requested_categories() -> void:
	var words := WordDatabase.get_random_words(WORD_COUNT, ["animals"])
	assert_that(words).is_not_empty()
	for word: Dictionary in words:
		assert_that(word.image).contains("/assets/images/animals/")


func test_get_random_words_with_multiple_categories_only_draws_from_those() -> void:
	var words := WordDatabase.get_random_words(WORD_COUNT, ["animals", "vehicles"])
	for word: Dictionary in words:
		var in_animals: bool = word.image.contains("/assets/images/animals/")
		var in_vehicles: bool = word.image.contains("/assets/images/vehicles/")
		assert_that(in_animals or in_vehicles).is_true()


func test_get_random_words_empty_categories_means_no_filter() -> void:
	var words := WordDatabase.get_random_words(WORD_COUNT, [])
	assert_that(words).has_size(WORD_COUNT)


func _unique_count(values: Array[String]) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()
