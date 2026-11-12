extends Node3D
## Keeps the node upright in the world while its parent turns, e.g. a torch's flame burning upwards however the hand holds it

func _process(_delta: float) -> void:
	global_basis = Basis.IDENTITY.scaled(global_basis.get_scale())
