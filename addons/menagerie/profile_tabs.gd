@tool
extends TabContainer

enum {
	ALL = -1,
	CHARACTERS,
	STRUCTURES,
	THINGS,
}

@export_group("Cofiguration")
@export var _all_tab: Control

func _ready() -> void:
	set_tab_icon(CHARACTERS, preload("uid://btd64iwc2p3sh"))
	set_tab_title(CHARACTERS, "%s" % [get_tab_control(CHARACTERS).name])
	set_tab_icon(STRUCTURES, preload("uid://bes0anop2dh5u"))
	set_tab_icon(THINGS, preload("uid://c4udocqr7qeyj"))
	_on_tab_changed(current_tab)

func _on_tab_changed(tab: int) -> void:
	if tab < 0:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_all_tab.visible = true
	else:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		_all_tab.visible = false
