class_name AssetSelectionEffect extends Node

@export
var outline_material:Material

func toggle_selection(asset:Node3D, enabled:bool) -> void:
	var new_material:Material
	var expected_existing:Material
	
	if enabled:
		new_material = outline_material
		expected_existing = null
	else:
		new_material = null
		expected_existing = outline_material
		
	MaterialUtils.set_overlay_material(asset, new_material, expected_existing)
