extends GdUnitTestSuite
## ResourceIds name resources by their file's uid:// (and their id inside it), and find them again; checked on a
## small data file without assets, so CI runs it (the equipment's requestable ids are in with_assets/)

## A file with a uid and a sub-resource (its box shape), and no assets
const SHAPE_FILE: String = "res://data/structures/tiles/tile_shape.tres"

func _shape_file() -> Resource:
	return load(SHAPE_FILE)

func test_files_are_named_by_uid() -> void:
	var file: Resource = _shape_file()
	var id: String = ResourceId.of(file)
	assert_str(id).starts_with("uid://")
	assert_object(ResourceId.find(id)).is_same(file)
	assert_str(ResourceId.get_file_path(id)).is_equal(file.resource_path)

func test_resources_inside_files_are_named_and_found() -> void:
	var box: Resource = _shape_file().get("_shape")
	var id: String = ResourceId.of(box)
	assert_str(id).contains(ResourceId.SEPARATOR)
	assert_object(ResourceId.find(id)).is_same(box)
	assert_str(ResourceId.get_file_path(id)).is_equal(SHAPE_FILE)

func test_runtime_resources_have_no_id() -> void:
	assert_str(ResourceId.of(BoxShape3D.new())).is_empty()
	assert_str(ResourceId.of(null)).is_empty()

func test_unknown_ids_find_nothing_without_errors() -> void:
	assert_object(ResourceId.find("")).is_null()
	assert_object(ResourceId.find("uid://doesnotexist")).is_null()
	assert_object(ResourceId.find("res://does/not/exist.tres")).is_null()
	assert_str(ResourceId.get_file_path("uid://doesnotexist")).is_empty()

func test_plain_paths_still_find_their_resource() -> void:
	assert_object(ResourceId.find(SHAPE_FILE)).is_same(_shape_file())
