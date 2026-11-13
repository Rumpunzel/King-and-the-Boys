extends GdUnitTestSuite
## ResourceIds name resources by their file's uid:// (and their id inside it), and find them again; checked on a
## small fixture file, so CI runs it (the equipment's requestable ids are in with_assets/)

## A file with a uid and a sub-resource (its material)
const SAMPLE_FILE: String = "res://tests/fixtures/resource_id_sample.tres"

func _sample_file() -> Resource:
	return load(SAMPLE_FILE)

func test_files_are_named_by_uid() -> void:
	var file: Resource = _sample_file()
	var id: String = ResourceId.of(file)
	assert_str(id).starts_with("uid://")
	assert_object(ResourceId.find(id)).is_same(file)
	assert_str(ResourceId.get_file_path(id)).is_equal(file.resource_path)

func test_resources_inside_files_are_named_and_found() -> void:
	var material: Resource = _sample_file().get("material")
	var id: String = ResourceId.of(material)
	assert_str(id).contains(ResourceId.SEPARATOR)
	assert_object(ResourceId.find(id)).is_same(material)
	assert_str(ResourceId.get_file_path(id)).is_equal(SAMPLE_FILE)

func test_runtime_resources_have_no_id() -> void:
	assert_str(ResourceId.of(BoxShape3D.new())).is_empty()
	assert_str(ResourceId.of(null)).is_empty()

func test_unknown_ids_find_nothing_without_errors() -> void:
	assert_object(ResourceId.find("")).is_null()
	assert_object(ResourceId.find("uid://doesnotexist")).is_null()
	assert_object(ResourceId.find("res://does/not/exist.tres")).is_null()
	assert_str(ResourceId.get_file_path("uid://doesnotexist")).is_empty()

func test_plain_paths_still_find_their_resource() -> void:
	assert_object(ResourceId.find(SAMPLE_FILE)).is_same(_sample_file())
