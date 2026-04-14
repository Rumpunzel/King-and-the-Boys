class_name ProfileSpawnTable
extends SpawnTable

@export var _profile_distribution: Dictionary[Profile, float]

func _get_profiles() -> Array[Profile]: return _profile_distribution.keys()
func _get_weights() -> Array[float]: return _profile_distribution.values()
func _get_weight(profile: Profile) -> float: return _profile_distribution[profile]
