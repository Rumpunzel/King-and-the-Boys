extends GdUnitTestSuite
## Menagerie's sky box buttons show the saved choice, or the one pressed in the scene file if the saved one is gone

const SKY_BOX_BUTTON: String = "uid://2sxvt8rs6p8d"  # addons/menagerie/preview/sky_box_button.gd
const CONFIG_NAME: String = "sky_box_button_test"

var _row: HBoxContainer
var _config: Config
var _pressed_skies: Array[String] = []

func before_test() -> void:
	_pressed_skies.clear()
	_config = auto_free(Config.new())
	_config.set("_scope", Config.Scope.USER)
	_config.set("_config_file_name", CONFIG_NAME)
	add_child(_config)
	_row = auto_free(HBoxContainer.new())

func after_test() -> void:
	DirAccess.remove_absolute("user://%s.cfg" % CONFIG_NAME)

## Two buttons in one group; [param pressed_in_file] is pressed before they are ready, as the scene file does
func _add_buttons(pressed_in_file: String) -> void:
	var group: ButtonGroup = ButtonGroup.new()
	for button_name: String in ["Autumn", "Fairy"]:
		var button: Button = Button.new()
		button.set_script(load(SKY_BOX_BUTTON))
		button.name = button_name
		button.toggle_mode = true
		button.button_group = group
		button.set("_config", _config)
		button.button_pressed = button_name == pressed_in_file
		button.connect("sky_box_pressed", func(_sky_box: PanoramaSkyMaterial) -> void: _pressed_skies.append(button_name))
		_row.add_child(button)
	add_child(_row)

func _pressed_buttons() -> Array[String]:
	var pressed: Array[String] = []
	for button: Button in _row.get_children(): if button.button_pressed: pressed.append(button.name)
	return pressed

func test_the_saved_choice_is_the_one_pressed() -> void:
	_config.update_value_in_config("Fairy", "SkyBox", "selected_sky_box")
	_add_buttons("Autumn")
	assert_array(_pressed_buttons()).contains_exactly(["Fairy"])
	assert_array(_pressed_skies).contains_exactly(["Fairy"])

func test_a_saved_choice_that_is_gone_leaves_the_scene_files() -> void:
	_config.update_value_in_config("Gone", "SkyBox", "selected_sky_box")
	_add_buttons("Autumn")
	assert_array(_pressed_buttons()).contains_exactly(["Autumn"])
	assert_array(_pressed_skies).contains_exactly(["Autumn"])
