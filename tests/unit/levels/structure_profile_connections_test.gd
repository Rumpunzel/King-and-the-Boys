extends GdUnitTestSuite
## A profile's direct connection check agrees with its turned list of connections, for every tile shape and turn

const TILES: Array[String] = [
	"res://tests/fixtures/tiles/dead_end.tres",
	"res://tests/fixtures/tiles/straight.tres",
	"res://tests/fixtures/tiles/corner.tres",
	"res://tests/fixtures/tiles/junction.tres",
	"res://tests/fixtures/tiles/crossing.tres",
	"res://tests/fixtures/tiles/solid.tres",
]

func test_has_connection_matches_the_turned_connections() -> void:
	for path: String in TILES:
		var profile: StructureProfile = load(path)
		for clockwise_turns: int in range(-4, 8):
			var connections: Array[Level.Direction] = profile.get_connections(clockwise_turns)
			for direction: Level.Direction in Level.Direction.values():
				assert_bool(profile.has_connection(direction, clockwise_turns)).override_failure_message("%s turned %d towards %d" % [path, clockwise_turns, direction]).is_equal(connections.has(direction))
