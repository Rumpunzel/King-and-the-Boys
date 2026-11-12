@icon("uid://ba48wfee2hq2x")
class_name TileLiftAnimation
extends Resource
## How a lifted tile moves (see [TileLift]): it rises, hangs wobbling, spins to its new turn and drops back with a bounce.
## Its particles are asset scenes: set it in scenes (e.g. the dungeon level), not by [code]preload[/code] in scripts

## How high the tile hangs, in metres
@export_range(0.0, 5.0, 0.05, "or_greater") var height: float = 1.6
## Seconds it takes to rise
@export_range(0.0, 2.0, 0.01, "or_greater") var rise_duration: float = 0.4
## Seconds a spin to the next turn takes
@export_range(0.0, 2.0, 0.01, "or_greater") var spin_duration: float = 0.35
## Seconds it takes to drop back; it starts halfway through the last spin
@export_range(0.0, 2.0, 0.01, "or_greater") var drop_duration: float = 0.5
## Most the hanging tile tips over, in degrees
@export_range(0.0, 30.0, 0.1) var wobble_degrees: float = 2.5
## Radians per second of the slower of the two wobble axes
@export_range(0.0, 10.0, 0.1) var wobble_speed: float = 2.3
@export_group("Particles")
## Played on the floor under the tile as it rises, e.g. dust; its [GPUParticles3D] each emit once
@export var rise_particles: PackedScene
## Played on the floor as the dropping tile first hits it
@export var landing_particles: PackedScene
## Shown under the tile while it hangs in the air (e.g. magic sparkles and a glow), riding with it; its [GPUParticles3D] stop
## emitting as it drops and it goes once they have faded
@export var hover_particles: PackedScene
## When the dropping tile first hits the floor, as a share of [member drop_duration] (the bounce's first touch)
@export_range(0.0, 1.0, 0.01) var landing_time: float = 0.36
