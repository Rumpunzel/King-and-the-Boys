@tool
@icon("uid://btrwws8oarj4m")
class_name BodyPoolsProperty
extends EditorProperty

## Edits the pools of a [ModelConfigurationRandom] at a glance: every body part of a body (the parts no slot owns) with whether it
## is randomized and a thumbnail per mesh (shown on the body's head), pressed while the mesh is in the part's pool. Parts without a pool roll from all their
## meshes, so they show all pressed. Changes go through the inspector, so they can be undone and are saved with the configuration

const OUT_OF_POOL: Color = Color(1.0, 1.0, 1.0, 0.3)
const THUMBNAIL_SIZE: Vector2 = Vector2(64, 64)
const Thumbnails: GDScript = preload("uid://d16hfhvxd3tl1")

var _body_option: OptionButton = OptionButton.new()
var _sections: VBoxContainer = VBoxContainer.new()
var _bodies: Array[PackedScene] = []
var _is_rebuild_queued: bool = false
## Renders each mesh on its body's head, see body_part_thumbnails.gd
var _thumbnails: Node = Thumbnails.new()

func _init() -> void:
	_body_option.tooltip_text = "The body whose parts are shown"
	_body_option.item_selected.connect(func(_index: int) -> void: _queue_rebuild())
	add_child(_body_option)
	add_focusable(_body_option)
	add_child(_sections)
	set_bottom_editor(_sections)
	add_child(_thumbnails)

## The bodies equipment exists for, i.e. every [ModularModel] scene a type dresses
static func find_bodies() -> Array[PackedScene]:
	var bodies: Array[PackedScene] = []
	for equipment_type: EquipmentType in EquipmentType.find_all():
		if equipment_type.model and not bodies.has(equipment_type.model): bodies.append(equipment_type.model)
	return bodies

## The body [param configuration] is most likely for: the first that has every part it randomizes
static func guess_body(configuration: ModelConfigurationRandom, bodies: Array[PackedScene]) -> int:
	for index: int in bodies.size():
		var model_parts: ModularModelParts = ModularModelParts.of(bodies[index])
		if model_parts and Array(configuration.randomized_parts).all(func(part_key: String) -> bool: return model_parts.part_keys.has(part_key)): return index
	return 0

func _update_property() -> void:
	var configuration: ModelConfigurationRandom = get_edited_object() as ModelConfigurationRandom
	if not configuration: return
	# E.g. its gender, which decides the meshes listed; the inspector only updates the edited property
	if not configuration.changed.is_connected(_queue_rebuild): configuration.changed.connect(_queue_rebuild)
	if _bodies.is_empty():
		_bodies = find_bodies()
		for body: PackedScene in _bodies: _body_option.add_item(body.resource_path.get_file().get_basename().capitalize())
		if not _bodies.is_empty(): _body_option.select(guess_body(configuration, _bodies))
	_queue_rebuild()

func _queue_rebuild() -> void:
	if _is_rebuild_queued: return
	_is_rebuild_queued = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_is_rebuild_queued = false
	for child: Node in _sections.get_children(): child.queue_free()
	var configuration: ModelConfigurationRandom = get_edited_object() as ModelConfigurationRandom
	if not configuration or _bodies.is_empty(): return
	var model_parts: ModularModelParts = ModularModelParts.of(_bodies[_body_option.selected], configuration.gender)
	if not model_parts: return
	for part: int in model_parts.get_body_parts(): _sections.add_child(_make_section(configuration, _bodies[_body_option.selected], part))

func _make_section(configuration: ModelConfigurationRandom, body: PackedScene, part: int) -> Control:
	var model_parts: ModularModelParts = ModularModelParts.of(body, configuration.gender)
	var part_key: String = model_parts.get_part_key(part)
	var numbers: PackedStringArray = model_parts.get_mesh_numbers(part)
	var options: PackedStringArray = model_parts.get_mesh_options(part)
	var randomized: bool = configuration.randomized_parts.has(part_key)
	var section: VBoxContainer = VBoxContainer.new()
	var header: HBoxContainer = HBoxContainer.new()
	var randomize_box: CheckBox = CheckBox.new()
	var in_pool: int = Array(numbers).filter(func(number: String) -> bool: return configuration.is_in_pool(part_key, number)).size()
	randomize_box.text = "%s  (%d / %d)" % [part_key.capitalize(), in_pool, numbers.size()] if randomized else part_key.capitalize()
	randomize_box.tooltip_text = "Rolled per character; unchecked, the part shows its default mesh"
	randomize_box.button_pressed = randomized
	randomize_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	randomize_box.toggled.connect(_set_randomized.bind(part_key))
	header.add_child(randomize_box)
	if randomized:
		if in_pool == 0: randomize_box.add_theme_color_override(&"font_color", Color.ORANGE_RED)
		for label: String in ["All", "None"]:
			var button: Button = Button.new()
			button.text = label
			button.flat = true
			button.pressed.connect(_set_pool.bind(part_key, numbers if label == "All" else PackedStringArray(), numbers))
			header.add_child(button)
	section.add_child(header)
	if not randomized: return section
	var flow: HFlowContainer = HFlowContainer.new()
	for index: int in numbers.size():
		var number: String = numbers[index]
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_pressed = configuration.is_in_pool(part_key, number)
		button.text = "none" if options[index].is_empty() else number
		button.tooltip_text = "%s %s" % [part_key.capitalize(), button.text]
		button.custom_minimum_size = THUMBNAIL_SIZE + Vector2(0, 18)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.modulate = Color.WHITE if button.button_pressed else OUT_OF_POOL
		button.toggled.connect(_set_number.bind(part_key, number, numbers))
		_thumbnails.call(&"request", body, configuration.gender, part, options[index], _on_thumbnail.bind(button))
		flow.add_child(button)
	section.add_child(flow)
	section.add_child(HSeparator.new())
	return section

func _on_thumbnail(thumbnail: Texture2D, button: Button) -> void:
	if is_instance_valid(button): button.icon = thumbnail

func _set_randomized(randomized: bool, part_key: String) -> void:
	var configuration: ModelConfigurationRandom = get_edited_object() as ModelConfigurationRandom
	var parts: PackedStringArray = configuration.randomized_parts.duplicate()
	if randomized and not parts.has(part_key): parts.append(part_key)
	if not randomized and parts.has(part_key): parts.remove_at(parts.find(part_key))
	# One change, so one undo; a part's pool stays while it is not randomized, so checking it again brings its choice back
	emit_changed(&"randomized_parts", parts)
	_queue_rebuild()

func _set_number(enabled: bool, part_key: String, number: String, numbers: PackedStringArray) -> void:
	var configuration: ModelConfigurationRandom = get_edited_object() as ModelConfigurationRandom
	emit_changed(get_edited_property(), configuration.with_pool_number(part_key, number, enabled, numbers))
	_queue_rebuild()

func _set_pool(part_key: String, pool: PackedStringArray, numbers: PackedStringArray) -> void:
	var configuration: ModelConfigurationRandom = get_edited_object() as ModelConfigurationRandom
	emit_changed(get_edited_property(), configuration.with_pool(part_key, pool, numbers))
	_queue_rebuild()
