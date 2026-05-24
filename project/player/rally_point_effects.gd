extends Node3D

@export
var rally_point_effect_scene:PackedScene

var _effect_mapping:Dictionary[int,Node3D]

func _ready() -> void:
	assert(rally_point_effect_scene, "%s: Rally point effect scene not set!" % name)
	
	if not rally_point_effect_scene:
		queue_free()
		return

	SignalBus.on_building_selected.connect(_on_building_selected)
	SignalBus.on_building_deselected.connect(_on_building_deselected)

func _exit_tree() -> void:
	for comp_id:int in _effect_mapping:
		var rally_point_component := instance_from_id(comp_id) as RallyPointComponent
		if rally_point_component:
			_deregister_changes(rally_point_component)
			
	_effect_mapping.clear()
		
func _on_building_selected(building:Building) -> void:
	var rally_point_component:RallyPointComponent = RallyPointComponent.get_component(building, false)
	if not rally_point_component:
		return
		
	_register_changes(rally_point_component)
	_add_update_indicator(rally_point_component)
	
func _on_building_deselected(building:Building) -> void:
	var rally_point_component:RallyPointComponent = RallyPointComponent.get_component(building, false)
	if not rally_point_component:
		return
	
	_remove_indicator(rally_point_component)
	_deregister_changes(rally_point_component)

func _add_update_indicator(rally_point_component:RallyPointComponent) -> void:
	var rally_point:Vector3 = rally_point_component.rally_point
	if rally_point == RallyPointComponent.NO_RALLY_POINT_SET:
		return
	
	var id:int = rally_point_component.get_instance_id()
	var visuals:Node3D = _effect_mapping.get(id)
	if not visuals:
		visuals = rally_point_effect_scene.instantiate()
		_effect_mapping[id] = visuals
		add_child(visuals)
		
	# GroundActionIndicator
	if visuals.has_method("display_at"):
		visuals.display_at(rally_point)
	else:
		visuals.global_position = rally_point	
		visuals.show()
		
func _remove_indicator(rally_point_component:RallyPointComponent) -> void:
	var id:int = rally_point_component.get_instance_id()
	var visuals:Node3D = _effect_mapping.get(id)
	
	if visuals:
		_effect_mapping.erase(id)
		visuals.queue_free()

func _register_changes(rally_point_component:RallyPointComponent) -> void:
	if not rally_point_component.rally_point_set.is_connected(_add_update_indicator):
		rally_point_component.rally_point_set.connect(_add_update_indicator.bind(rally_point_component))
		
	if not rally_point_component.rally_point_removed.is_connected(_remove_indicator):
		rally_point_component.rally_point_removed.connect(_remove_indicator.bind(rally_point_component))
	
func _deregister_changes(rally_point_component:RallyPointComponent) -> void:
	if rally_point_component.rally_point_set.is_connected(_add_update_indicator):
		rally_point_component.rally_point_set.disconnect(_add_update_indicator)
		
	if rally_point_component.rally_point_removed.is_connected(_remove_indicator):
		rally_point_component.rally_point_removed.disconnect(_remove_indicator)
