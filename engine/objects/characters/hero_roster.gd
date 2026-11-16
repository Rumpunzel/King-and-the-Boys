@tool
@icon("uid://d3wqipxx8dw13")
class_name HeroRoster
extends Resource
## The heroes a player may pick in the lobby

@export var heroes: Array[CharacterProfile] = []


## Whether the profile is one of the roster's heroes
func has(profile: CharacterProfile) -> bool:
	return profile != null and heroes.has(profile)
