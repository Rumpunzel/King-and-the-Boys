extends GdUnitTestSuite
## The moves bar shows used, undoable, held and left moves of a character

const ModelFreeWorld = preload("uid://is6upkdhky8n")  # tests/fixtures/model_free_world.gd
const MOVES_BAR_SCENE: String = "uid://b8ix8nx66t01e"  # user_interface/hud/moves_bar.tscn

func _states_of(moves_bar: MovesBar) -> Array:
	return moves_bar.get("_states")

## Kept out of the tree: a character there needs a level
func _character() -> Character:
	return auto_free(ModelFreeWorld.load_hero_profile().create(-1, Transform3D.IDENTITY))

func _moves_bar_of(character: Character) -> MovesBar:
	var moves_bar: MovesBar = auto_free((load(MOVES_BAR_SCENE) as PackedScene).instantiate())
	add_child(moves_bar)
	moves_bar.character = character
	return moves_bar

func test_the_held_cost_shows_after_the_moves_used() -> void:
	var character: Character = _character()
	var speed: int = character.profile.speed
	assert_int(speed).is_greater_equal(2)
	var moves_bar: MovesBar = _moves_bar_of(character)
	character.movement_points = speed - 1
	character.held_cost = 1
	assert_int(_states_of(moves_bar)[0]).is_equal(MovesBar.MoveState.USED)
	assert_int(_states_of(moves_bar)[1]).is_equal(MovesBar.MoveState.HELD)
	character.undo_steps = 1
	assert_int(_states_of(moves_bar)[0]).is_equal(MovesBar.MoveState.UNDOABLE)
	assert_int(_states_of(moves_bar)[1]).is_equal(MovesBar.MoveState.HELD)
	character.held_cost = 0
	assert_int(_states_of(moves_bar)[1]).is_equal(MovesBar.MoveState.LEFT)

func test_the_held_cost_never_overflows_the_bar() -> void:
	var character: Character = _character()
	var moves_bar: MovesBar = _moves_bar_of(character)
	character.held_cost = character.profile.speed + 3
	assert_int(_states_of(moves_bar).size()).is_equal(character.profile.speed)
	assert_bool(_states_of(moves_bar).has(MovesBar.MoveState.LEFT)).is_false()
