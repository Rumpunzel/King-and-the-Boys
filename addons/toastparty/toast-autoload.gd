extends Node

const label_resource = preload("uid://dugii0837nslt")

# {Vector3i(Toaster.HorizontalDirection, Toaster.VerticalDirection, Toaster.Gravity): Array[ToastLabel]}
var labels: Dictionary[Vector3i, Array] = {}

# parent node
var canvas_layer: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ToastPartyLayer"
	canvas_layer.layer = 128
	add_child(canvas_layer)
	# TODO: We need Debounce function
	# Connect signal resize to _on_resize
	# get_tree().get_root().connect("size_changed", _on_resize, 1)

func remove_label_from_array(label: ToastLabel):
	var label_position_vector: Vector3i = label.get_position_vector()
	labels[label_position_vector].erase(label)
	_update_label_positions(label_position_vector)

func _add_new_label(config: Toaster.ToasterConfig):
	# Create a new label
	var label: ToastLabel = label_resource.instantiate()
	label.init(config)
	canvas_layer.add_child(label)
	label.remove_label.connect(remove_label_from_array)
	var label_position_vector: Vector3i = label.get_position_vector()
	var existing_labels: Array[ToastLabel] = labels.get_or_add(label_position_vector, [] as Array[ToastLabel])
	match config.gravity:
		Toaster.Gravity.TOP: existing_labels.insert(0, label)
		Toaster.Gravity.BOTTOM: existing_labels.append(label)
		_: push_error("Toaster.Gravity %s not implemented!" % config.gravity)
	_update_label_positions(label_position_vector)

func _update_label_positions(label_position_vector: Vector3i) -> void:
	var existing_labels: Array[ToastLabel] = labels[label_position_vector]
	# Move all labels to new positions when a new label is added
	for index: int in existing_labels.size():
		var existing_label: ToastLabel = existing_labels[index]
		existing_label.move_to(index)

## Event resize
func _on_resize():
	for _label: ToastLabel in labels.values(): _label.update_x_position()

func show(config: Toaster.ToasterConfig):
	_add_new_label(config)
