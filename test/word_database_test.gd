extends GdUnitTestSuite
## Tests for [autoload WordDatabase] (scripts/word_database.gd): the random
## word picker and the per-locale audio path resolver, both pure logic that
## doesn't touch the scene tree.

const WORD_COUNT := 45 # Keep in sync with WordDatabase.WORDS.


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


func _unique_count(values: Array[String]) -> int:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size()
