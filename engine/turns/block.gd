@icon("uid://3xn0cgn4onrw")
class_name Block
extends RefCounted
## One figure blocking another on the same tile, refereed by the host (see [TurnManager]): block dice decide who falls and
## whether the defender is pushed. Nobody takes damage; a fallen figure lies [constant Character.Posture.DOWN] until it gets up.
## Strength decides the dice: each side adds 1 for every other standing figure of its own on the tile (an assist), as long as
## the other side has only one standing figure there.

enum Face {
	ATTACKER_DOWN,
	BOTH_DOWN,
	PUSH,
	DEFENDER_STUMBLES,
	DEFENDER_DOWN,
}

## The six faces of a block die
const FACES: Array[Face] = [Face.ATTACKER_DOWN, Face.BOTH_DOWN, Face.PUSH, Face.PUSH, Face.DEFENDER_STUMBLES, Face.DEFENDER_DOWN]

var attacker: Character
var defender: Character
## The dice rolled, and the one that counts
var dice: Array[Face] = []
var chosen: Face = Face.PUSH
var attacker_picks: bool = true
## Where the defender stood, and where it was pushed to (the same cell if it was not)
var defender_cell: Vector2i
var pushed_to: Vector2i

func _init(blocking: Character, blocked: Character) -> void:
	attacker = blocking
	defender = blocked
	defender_cell = blocked.grid_cell
	pushed_to = blocked.grid_cell

## Host only: rolls the dice, picks the face best for whoever picks (players pick their own later), and plays it out on the
## board with [param random] (a push picks its way with it)
func resolve(level: Level, random: RandomNumberGenerator) -> void:
	var attack: int = get_strength(attacker, level)
	var defence: int = get_strength(defender, level)
	attacker_picks = attack >= defence
	for _die: int in count_dice(attack, defence): dice.append(FACES[random.randi() % FACES.size()])
	chosen = pick_best(dice, attacker_picks, _stumbles_down())
	apply(chosen, level, random)

## Host only: plays out [param face]: who falls, and the push (the attacker does not follow)
func apply(face: Face, level: Level, random: RandomNumberGenerator) -> void:
	match face:
		Face.ATTACKER_DOWN:
			attacker.posture = Character.Posture.DOWN
		Face.BOTH_DOWN:
			attacker.posture = Character.Posture.DOWN
			defender.posture = Character.Posture.DOWN
		Face.PUSH:
			_push(level, random)
		Face.DEFENDER_STUMBLES:
			_push(level, random)
			if _stumbles_down(): defender.posture = Character.Posture.DOWN
		Face.DEFENDER_DOWN:
			_push(level, random)
			defender.posture = Character.Posture.DOWN

## @returns whether the defender was pushed off its tile
func was_pushed() -> bool:
	return pushed_to != defender_cell

## A stumbling defender keeps its feet only if it is at least as agile as the attacker
func _stumbles_down() -> bool:
	return defender.profile.agility < attacker.profile.agility

## Onto a free spot of a neighbouring tile through a passage, picked at random; with none, the defender stays
func _push(level: Level, random: RandomNumberGenerator) -> void:
	var cell: Vector2i = defender.grid_cell
	var ways: Array[Level.Direction] = []
	for direction: Level.Direction in Level.Direction.values():
		if level.is_passage(cell, direction) and not level.get_free_spots(cell + Level.direction_to_vector(direction), defender).is_empty(): ways.append(direction)
	if ways.is_empty(): return
	var way: Level.Direction = ways[random.randi() % ways.size()]
	pushed_to = cell + Level.direction_to_vector(way)
	# Facing back towards the one who pushed it
	var spot: Vector2 = level.get_free_spots(pushed_to, defender).front()
	defender.place_on_grid(pushed_to, spot, Level.get_opposite(way))

## How many dice a block rolls: 1 at equal strength, 2 if one side is stronger, 3 if the attacker is at least twice as strong
static func count_dice(attack: int, defence: int) -> int:
	if attack == defence: return 1
	if attack >= defence * 2: return 3
	return 2

## The face best for the side that picks: the attacker wants the defender down, the defender wants the attacker down or at
## least to stay; a stumble counts as a fall if [param stumbles_down]
static func pick_best(faces: Array[Face], by_attacker: bool, stumbles_down: bool) -> Face:
	var best: Face = faces.front()
	for face: Face in faces:
		if _score(face, stumbles_down) * (1 if by_attacker else -1) > _score(best, stumbles_down) * (1 if by_attacker else -1): best = face
	return best

## How good [param face] is for the attacker
static func _score(face: Face, stumbles_down: bool) -> int:
	match face:
		Face.ATTACKER_DOWN: return -2
		Face.BOTH_DOWN: return -1
		Face.PUSH: return 1
		Face.DEFENDER_STUMBLES: return 3 if stumbles_down else 1
		Face.DEFENDER_DOWN: return 3
	return 0

## [param character]'s strength in a block on its tile: its own plus an assist from every other standing figure of its side
## there, unless more than one standing enemy stands there too
static func get_strength(character: Character, level: Level) -> int:
	var allies: int = 0
	var enemies: int = 0
	for other: Character in get_standing_on(character.grid_cell, level):
		if other == character: continue
		if other.profile.group == character.profile.group: allies += 1
		else: enemies += 1
	return character.profile.strength + (allies if enemies <= 1 else 0)

## @returns the standing figures on [param cell]
static func get_standing_on(cell: Vector2i, level: Level) -> Array[Character]:
	var standing: Array[Character] = []
	for node: Node in level.get_tree().get_nodes_in_group(Character.GROUP):
		var character: Character = node as Character
		if not character or not character.visible or character.level != level or character.grid_cell != cell: continue
		if character.posture == Character.Posture.STANDING: standing.append(character)
	return standing
