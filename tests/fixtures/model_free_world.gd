extends RefCounted
## A level and a hero from profiles without models, so tests need no imported meshes or textures.
## The real profiles (data/) hold their model scenes and load them with themselves.
## The profiles are files because spawners replicate structures by their profile's path.

const LEVEL_SCENE: String = "res://engine/levels/level.tscn"
## Tiles of every shape; with rotations they fit any neighbourhood the level generator asks for
const TILE_SET: String = "res://tests/fixtures/tiles/tile_set.tres"
const STARTING_TILE: String = "res://tests/fixtures/tiles/crossing.tres"
const WALL_TILE: String = "res://tests/fixtures/tiles/wall.tres"
const HERO: String = "res://tests/fixtures/hero.tres"

## @returns a level with the model-free tiles; add it to the tree, then call [method Level.build_level]
static func create_level() -> Level:
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	level.set(&"_starting_tile", load(STARTING_TILE))
	level.set(&"_wall_tile", load(WALL_TILE))
	level.set(&"_tile_set", load(TILE_SET))
	return level

static func load_hero_profile() -> CharacterProfile:
	return load(HERO)
