class_name AssetSelectionEffect extends Node

@export
var outline_material:Material

## If > 0 then automatically toggle the selection off after the given interval if it is still enabled
@export
var auto_disable_delay:float = -1.0
	
func toggle_selection(asset:Node3D, enabled:bool) -> void:	
	var new_material:Material
	var expected_existing:Material
	
	if enabled:
		new_material = outline_material
		expected_existing = null
		if auto_disable_delay > 0:
			_schedule_disable(asset)
	else:
		new_material = null
		expected_existing = outline_material
		
	MaterialUtils.set_overlay_material(asset, new_material, expected_existing)

func _schedule_disable(asset:Node3D) -> void:
	var timer := Timer.new()
	timer.name = "DeselectTimer-%s" % asset.name
	timer.wait_time = auto_disable_delay
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_disable_selection.bind(timer, asset.get_instance_id()))
	add_child(timer)

func _disable_selection(timer:Timer, asset_id:int) -> void:
	timer.queue_free()
	var asset:Node3D = instance_from_id(asset_id) as Node3D
	if asset:
		toggle_selection(asset, false)
