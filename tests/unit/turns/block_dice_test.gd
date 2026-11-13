extends GdUnitTestSuite
## Block dice: how many are rolled, who picks, and which face each side picks

func test_strength_decides_the_dice() -> void:
	assert_int(Block.count_dice(3, 3)).is_equal(1)
	assert_int(Block.count_dice(4, 3)).is_equal(2)
	assert_int(Block.count_dice(6, 3)).is_equal(3)
	assert_int(Block.count_dice(2, 3)).is_equal(2)
	assert_int(Block.count_dice(1, 3)).is_equal(2)

func test_a_die_has_six_faces_with_two_pushes() -> void:
	assert_int(Block.FACES.size()).is_equal(6)
	assert_int(Block.FACES.count(Block.Face.PUSH)).is_equal(2)
	for face: Block.Face in Block.Face.values(): assert_bool(Block.FACES.has(face)).is_true()

func test_the_attacker_picks_the_defender_down() -> void:
	var faces: Array[Block.Face] = [Block.Face.ATTACKER_DOWN, Block.Face.PUSH, Block.Face.DEFENDER_DOWN]
	assert_int(Block.pick_best(faces, true, true)).is_equal(Block.Face.DEFENDER_DOWN)
	assert_int(Block.pick_best(faces, false, true)).is_equal(Block.Face.ATTACKER_DOWN)

func test_a_stumble_counts_as_a_fall_only_against_a_clumsier_defender() -> void:
	var faces: Array[Block.Face] = [Block.Face.PUSH, Block.Face.DEFENDER_STUMBLES]
	assert_int(Block.pick_best(faces, true, true)).is_equal(Block.Face.DEFENDER_STUMBLES)
	# As good as a push for an agile defender: the first of the two stays
	assert_int(Block.pick_best(faces, true, false)).is_equal(Block.Face.PUSH)

func test_the_defender_would_rather_go_down_together_than_alone() -> void:
	var faces: Array[Block.Face] = [Block.Face.DEFENDER_DOWN, Block.Face.BOTH_DOWN]
	assert_int(Block.pick_best(faces, false, true)).is_equal(Block.Face.BOTH_DOWN)
