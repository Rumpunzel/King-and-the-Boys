@icon("uid://cmbhx5v0d8ri8")
class_name AwarenessMarks
extends Control
## Shows what each monster knows of the heroes, on every peer, from its replicated [member Agent.awareness]: a "!" over one
## hunting a hero (popping as it notices), a "?" over one going to look where it last noticed one, nothing over a roaming one
## or one this peer does not show ([member Character.shown]). Only shows: [MonsterSenses] decides on the host.

const _HUNTING_COLOR: Color = Color(1.0, 0.36, 0.24)
const _INVESTIGATING_COLOR: Color = Color(1.0, 0.84, 0.36)
const _FONT_SIZE: int = 44
const _POP_SCALE: float = 1.6
const _POP_DURATION: float = 0.35

@export_group("Configuration")
@export var _level: Level

# Agent -> its mark
var _marks: Dictionary[Agent, Label] = {}

## @returns the mark for [param awareness]
static func mark_text(awareness: Agent.Awareness) -> String:
	match awareness:
		Agent.Awareness.HUNTING: return "!"
		Agent.Awareness.INVESTIGATING: return "?"
	return ""

## @returns the mark shown over [param agent]'s monster, [code]null[/code] if it has none (yet)
func get_mark(agent: Agent) -> Label:
	return _marks.get(agent)

func _process(_delta: float) -> void:
	if not _level: return
	for node: Node in get_tree().get_nodes_in_group(Character.GROUP):
		var character: Character = node as Character
		if not character or character.level != _level or character.profile.group != CharacterProfile.Groups.MONSTERS: continue
		var agent: Agent = character.get_parent() as Agent
		if agent and not _marks.has(agent): _add_mark(agent)
	var camera: Camera3D = get_viewport().get_camera_3d()
	for agent: Agent in _marks.keys():
		if agent.is_queued_for_deletion(): _remove_mark(agent)
		else: _place(agent, _marks[agent], camera)

func _add_mark(agent: Agent) -> void:
	var mark: Label = Label.new()
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_font_size_override(&"font_size", _FONT_SIZE)
	mark.add_theme_constant_override(&"outline_size", 10)
	mark.add_theme_color_override(&"font_outline_color", Color(0.08, 0.05, 0.04))
	mark.hide()
	add_child(mark)
	_marks[agent] = mark
	agent.awareness_changed.connect(_on_awareness_changed.bind(agent))
	# Before it is freed: a freed agent may not be a key any more
	agent.tree_exiting.connect(_on_agent_exiting.bind(agent), CONNECT_ONE_SHOT)

func _remove_mark(agent: Agent) -> void:
	if not _marks.has(agent): return
	var mark: Label = _marks[agent]
	_marks.erase(agent)
	mark.queue_free()

func _on_agent_exiting(agent: Agent) -> void:
	_remove_mark(agent)

func _place(agent: Agent, mark: Label, camera: Camera3D) -> void:
	var character: Character = agent.character
	mark.text = mark_text(agent.awareness)
	var anchor: Vector3 = character.get_heads_up_anchor()
	mark.visible = not mark.text.is_empty() and character.visible and character.shown and not (camera and camera.is_position_behind(anchor))
	if not mark.visible or not camera: return
	mark.add_theme_color_override(&"font_color", _HUNTING_COLOR if agent.awareness == Agent.Awareness.HUNTING else _INVESTIGATING_COLOR)
	mark.reset_size()
	mark.pivot_offset = mark.size / 2.0
	mark.position = camera.unproject_position(anchor) - mark.size / 2.0

func _on_awareness_changed(agent: Agent) -> void:
	if agent.awareness != Agent.Awareness.HUNTING or not _marks.has(agent): return
	# It noticed someone: the mark pops
	var mark: Label = _marks[agent]
	mark.scale = Vector2.ONE * _POP_SCALE
	mark.create_tween().tween_property(mark, "scale", Vector2.ONE, _POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
