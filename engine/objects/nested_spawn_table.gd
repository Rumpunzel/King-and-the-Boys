class_name NestedSpawnTable
extends SpawnTable

@export var _table_distribution: Dictionary[SpawnTable, float]

var _flat_profile_distribution: Dictionary[Profile, float]:
	get:
		if _flat_profile_distribution.is_empty(): _flat_profile_distribution = _get_flattened_profile_distribution()
		return _flat_profile_distribution

func _get_flattened_profile_distribution() -> Dictionary[Profile, float]:
	var flattened_profile_distribution: Dictionary[Profile, float] = {}
	for spawn_table: SpawnTable in _table_distribution.keys():
		var adjusted_spawn_table: Dictionary[Profile, float]
		if spawn_table: adjusted_spawn_table = spawn_table.get_profiles_with_weights_multiplied(_table_distribution[spawn_table])
		else: adjusted_spawn_table = {null: _table_distribution[null]}
		for profile: Profile in adjusted_spawn_table:
			if not flattened_profile_distribution.has(profile): flattened_profile_distribution[profile] = adjusted_spawn_table[profile]
			else: flattened_profile_distribution[profile] = flattened_profile_distribution[profile] + adjusted_spawn_table[profile]
	return flattened_profile_distribution

func _get_profiles() -> Array[Profile]: return _flat_profile_distribution.keys()
func _get_weights() -> Array[float]: return _flat_profile_distribution.values()
func _get_weight(profile: Profile) -> float: return _flat_profile_distribution[profile]
