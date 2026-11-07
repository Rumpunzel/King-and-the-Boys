extends SceneTree
## Headless test runner. Loads the test nodes only after the autoloads exist,
## because this script itself is compiled before them.
## Run: godot --headless --path . --script res://test/run_tests.gd

const TESTS: Array[String] = ["res://test/turns/turn_rules_test.gd"]

func _initialize() -> void:
	for test_path: String in TESTS:
		var test_script: GDScript = load(test_path)
		if not test_script or not test_script.can_instantiate():
			printerr("FAIL could not load %s" % test_path)
			quit(1)
			return
		root.add_child.call_deferred(test_script.new() as Node)
