extends Node3D
## Keeps the node upright in the world while its parent turns, e.g. a torch's flame burning upwards however the hand holds it.
## Under a skeleton (a hand's bone attachment) it straightens each time the skeleton has posed, after the attachment followed
## the bone, so it never lags a frame behind the hand; elsewhere every frame

var _skeleton: Skeleton3D

func _ready() -> void:
	var ancestor: Node = get_parent()
	while ancestor and not ancestor is Skeleton3D: ancestor = ancestor.get_parent()
	_skeleton = ancestor as Skeleton3D
	# Connected after the bone attachments above, so it runs after they moved
	if _skeleton: _skeleton.skeleton_updated.connect(_straighten)
	set_process(not _skeleton)

func _exit_tree() -> void:
	if _skeleton and _skeleton.skeleton_updated.is_connected(_straighten): _skeleton.skeleton_updated.disconnect(_straighten)

func _process(_delta: float) -> void:
	_straighten()

func _straighten() -> void:
	if is_visible_in_tree(): global_basis = Basis.IDENTITY.scaled(global_basis.get_scale())
