extends GdUnitTestSuite
## The tile set counts a tile's connections from its bit flag of directions

func test_counts_every_combination_of_the_four_directions() -> void:
	var tile_set: DungeonTileSet = DungeonTileSet.new()
	for bitflag: int in 16:
		var expected: int = 0
		for direction: int in 4: if bitflag & (1 << direction): expected += 1
		assert_int(tile_set.call("_count_true_bits", bitflag)).override_failure_message("Bit flag %d" % bitflag).is_equal(expected)
