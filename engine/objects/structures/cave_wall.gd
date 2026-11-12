extends Node3D
## An edge of the dungeon: one piece of cave wall among [member _variants], picked and turned by the grid cell it stands in, so
## neighbouring walls differ and every peer shows the same without syncing

@export var grid_size: float = 2.0

@export_group("Configuration")
@export var _variants: Array[Node3D]

func _ready() -> void:
	if _variants.is_empty(): return
	var cell_hash: int = absi(hash(Vector2i(roundi(global_position.x / grid_size), roundi(global_position.z / grid_size))))
	for index: int in _variants.size(): _variants[index].visible = index == cell_hash % _variants.size()
	rotation.y = (cell_hash / _variants.size() % 4) * PI * 0.5
