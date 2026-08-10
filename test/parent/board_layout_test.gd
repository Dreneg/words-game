extends GdUnitTestSuite
## Tests for BoardLayout (scripts/parent/board_layout.gd): the shared
## card-count <-> grid-columns/label mapping used by both Main (the actual
## grid) and ParentSettings (the option buttons' "RxC" labels).


func test_columns_for_known_options() -> void:
	assert_that(BoardLayout.columns_for(9, 4)).is_equal(3)
	assert_that(BoardLayout.columns_for(12, 4)).is_equal(4)
	assert_that(BoardLayout.columns_for(15, 4)).is_equal(5)


func test_columns_for_unknown_count_falls_back() -> void:
	assert_that(BoardLayout.columns_for(20, 6)).is_equal(6)


func test_label_for_known_options() -> void:
	assert_that(BoardLayout.label_for(9)).is_equal("3x3")
	assert_that(BoardLayout.label_for(12)).is_equal("3x4")
	assert_that(BoardLayout.label_for(15)).is_equal("3x5")


func test_label_for_unknown_count_falls_back_to_plain_number() -> void:
	assert_that(BoardLayout.label_for(20)).is_equal("20")
