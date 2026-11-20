extends "res://tests/fixtures/monster_test_suite.gd"
## Showing what monsters know (see AwarenessMarks, InvestigationMark): "!" over a hunting monster, "?" over an investigating one,
## nothing over a roaming one or one this peer does not show; the cell it investigates marked on the floor

const AWARENESS_MARKS: String = "uid://c4wrnmk2aw1ma"  # user_interface/hud/awareness_marks.tscn

var _marks: AwarenessMarks

func before_test() -> void:
	await super()
	_marks = auto_free((load(AWARENESS_MARKS) as PackedScene).instantiate())
	_marks.set("_level", _level)
	add_child(_marks)

func _investigation_mark(monster: Character) -> InvestigationMark:
	for child: Node in _agent(monster).get_children():
		if child is InvestigationMark: return child as InvestigationMark
	return null

func test_mark_text_per_awareness() -> void:
	assert_str(AwarenessMarks.mark_text(Agent.Awareness.ROAMING)).is_empty()
	assert_str(AwarenessMarks.mark_text(Agent.Awareness.HUNTING)).is_equal("!")
	assert_str(AwarenessMarks.mark_text(Agent.Awareness.INVESTIGATING)).is_equal("?")

func test_a_mark_shows_only_for_a_shown_monster_that_is_not_roaming() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	# As on a tile this peer revealed
	monster.shown = true
	await await_idle_frame()
	var label: Label = _marks.get_mark(_agent(monster))
	assert_object(label).is_not_null()
	assert_bool(label.visible).is_false()
	_agent(monster).awareness = Agent.Awareness.HUNTING
	await await_idle_frame()
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("!")
	monster.shown = false
	await await_idle_frame()
	assert_bool(label.visible).is_false()

func test_the_mark_pops_only_as_the_monster_starts_hunting() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	monster.shown = true
	await await_idle_frame()
	var agent: Agent = _agent(monster)
	var label: Label = _marks.get_mark(agent)
	agent.awareness = Agent.Awareness.HUNTING
	assert_float(label.scale.x).is_greater(1.0)
	await get_tree().create_timer(AwarenessMarks._POP_DURATION + 0.1).timeout
	assert_float(label.scale.x).is_equal_approx(1.0, 0.001)
	# The hunted hero stepped on: the same hunt
	agent.awareness_target = agent.awareness_target + Vector2i.ONE
	assert_float(label.scale.x).is_equal_approx(1.0, 0.001)

func test_a_freed_monster_takes_its_mark_along() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	await await_idle_frame()
	var agent: Agent = _agent(monster)
	assert_object(_marks.get_mark(agent)).is_not_null()
	agent.queue_free()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(_marks.get_child_count()).is_zero()

func test_the_investigation_mark_sits_on_the_target_cell_only_while_investigating() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	monster.shown = true
	var mark: InvestigationMark = _investigation_mark(monster)
	assert_object(mark).is_not_null()
	await await_idle_frame()
	assert_bool(mark.visible).is_false()
	var agent: Agent = _agent(monster)
	agent.awareness_target = _start_cell()
	agent.awareness = Agent.Awareness.INVESTIGATING
	await await_idle_frame()
	assert_bool(mark.visible).is_true()
	var floor_position: Vector3 = _level.grid_to_world_position(_start_cell())
	assert_float(mark.global_position.x).is_equal_approx(floor_position.x, 0.01)
	assert_float(mark.global_position.z).is_equal_approx(floor_position.z, 0.01)
	agent.awareness = Agent.Awareness.HUNTING
	await await_idle_frame()
	assert_bool(mark.visible).is_false()

func test_a_monster_freed_at_once_takes_its_mark_along() -> void:
	var monster: Character = await _spawn_monster_ahead(2, false)
	await await_idle_frame()
	var agent: Agent = _agent(monster)
	assert_object(_marks.get_mark(agent)).is_not_null()
	# Freed between two frames, e.g. by a coroutine a tween resumed
	agent.get_parent().remove_child(agent)
	agent.free()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(_marks.get_child_count()).is_zero()
