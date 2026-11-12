extends GdUnitTestSuite
## Stat modifiers change a value one strategy each, in order; lights are found on the meshes and looks that are them

func _add(amount: float) -> AddStatModifier:
	var modifier: AddStatModifier = AddStatModifier.new()
	modifier.amount = amount
	return modifier

func _multiply(factor: float) -> MultiplyStatModifier:
	var modifier: MultiplyStatModifier = MultiplyStatModifier.new()
	modifier.factor = factor
	return modifier

func test_modifiers_apply_in_order() -> void:
	assert_float(StatModifier.apply_all([_add(1.0), _multiply(2.0)], 1.5)).is_equal(5.0)
	assert_float(StatModifier.apply_all([_multiply(2.0), _add(1.0)], 1.5)).is_equal(4.0)
	assert_float(StatModifier.apply_all([], 1.5)).is_equal(1.5)

func test_a_look_is_the_lights_its_meshes_are() -> void:
	var light_source: LightSource = LightSource.new()
	var torch: ArrayMesh = ArrayMesh.new()
	torch.set_meta(LightSource.META, light_source)
	assert_object(LightSource.of_mesh(torch)).is_same(light_source)
	assert_object(LightSource.of_mesh(ArrayMesh.new())).is_null()
	assert_object(LightSource.of_mesh(null)).is_null()
	var part_mesh: EquipmentPartMesh = EquipmentPartMesh.new()
	part_mesh.male_mesh = torch
	part_mesh.female_mesh = torch
	var look: EquipmentLook = EquipmentLook.new()
	look.appearance = EquipmentAppearance.new()
	look.appearance.parts = [part_mesh]
	# Counted once, whichever body shows it
	assert_array(look.get_light_sources()).contains_exactly([light_source])
	assert_array(EquipmentLook.new().get_light_sources()).is_empty()
