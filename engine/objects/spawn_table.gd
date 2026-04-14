@abstract
class_name SpawnTable
extends Resource

var _total_weight: float = -1:
	get:
		if _get_weights().is_empty(): return -1
		if _total_weight < 0: _total_weight = _get_weights().reduce(func(sum: float, spawn_weight: float) -> float: return sum + spawn_weight)
		assert(_total_weight >= 0)
		return _total_weight

func get_spawn() -> Profile:
	var random_selection: float = randf() * _total_weight
	for profile: Profile in _get_profiles():
		var weight: float = _get_weight(profile)
		if random_selection < weight: return profile
		random_selection -= weight
	assert(false)
	return null

func get_profiles_with_weights_multiplied(factor: float) -> Dictionary[Profile, float]:
	var multiplied_spawns: Dictionary[Profile, float] = {}
	for profile: Profile in _get_profiles(): multiplied_spawns[profile] = _get_weight(profile) * factor
	return multiplied_spawns

@abstract func _get_profiles() -> Array[Profile]
@abstract func _get_weights() -> Array[float]
@abstract func _get_weight(profile: Profile) -> float
