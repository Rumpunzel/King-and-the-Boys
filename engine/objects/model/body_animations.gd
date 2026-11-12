@tool
@icon("uid://bk111xvhpbvwt")
class_name BodyAnimations
extends Resource

## A state a model rests in (its idle, while its player has passed, while it holds an ability), played on its
## [AnimationPlayer] (see [method Model.rest_in]): an [member entry] played once going in (e.g. sitting down), then its
## [member animations] one after another, one picked at random and kept, or a new one picked for every cycle (a single one
## simply loops), and an [member exit] played once leaving it (e.g. getting up)

enum Order {
	## One after another, from the first again after the last
	SEQUENCE,
	## One picked at random each time the model comes to rest, looping until something else plays
	RANDOM_ONCE,
	## A new one picked at random after every cycle
	RANDOM_EACH_CYCLE,
}

@export var animations: Array[Animation] = []:
	set(new_value):
		animations = new_value
		changed.emit()
@export var order: Order = Order.SEQUENCE:
	set(new_value):
		order = new_value
		changed.emit()
## Played once as the model comes to rest in these, before them
@export var entry: Animation:
	set(new_value):
		entry = new_value
		changed.emit()
## Played once as the model leaves them for something else
@export var exit: Animation:
	set(new_value):
		exit = new_value
		changed.emit()

## The animations that exist, leaving out empty entries the inspector leaves behind
func get_animations() -> Array[Animation]:
	var found: Array[Animation] = []
	for animation: Animation in animations:
		if animation: found.append(animation)
	return found

## Which animation plays first, as the model comes to rest
func get_first(count: int) -> int:
	if count <= 0: return -1
	return 0 if order == Order.SEQUENCE else randi() % count

## Which animation follows [param current] once its cycle ended, or [code]-1[/code] to keep looping it
func get_next(current: int, count: int) -> int:
	if count <= 1: return -1
	match order:
		Order.SEQUENCE: return (current + 1) % count
		Order.RANDOM_ONCE: return -1
		Order.RANDOM_EACH_CYCLE:
			# Another one, so a cycle is never just the same one again
			var next: int = randi() % (count - 1)
			return next + 1 if next >= current else next
	return -1
