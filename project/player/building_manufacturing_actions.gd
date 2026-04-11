class_name BuildingManufacturingActions extends Node

@export
var selection_manager:SelectionManager

var activate:bool:
	get:
		return is_processing_unhandled_input()
	set(value):
		set_process_unhandled_input(value)
	
func _ready() -> void:
	assert(selection_manager, "%s: SelectionManager not set" % name)	
		
func _unhandled_input(event: InputEvent) -> void:
	if not selection_manager or not selection_manager.any_buildings_same_team:
		return
		
	if event.is_action_pressed("build_marine"):
		_dispatch_build_marine()
	elif event.is_action_pressed("build_tank"):
		_dispatch_build_tank()
	elif event.is_action_pressed("build_artillery"):
		_dispatch_build_artillery()

func _dispatch_build_marine() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Marine)
	
func _dispatch_build_tank() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Tank)
	
func _dispatch_build_artillery() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Artillery)

func _dispatch_viable_build_order(type: ConstructionResource.Type) -> void:
	var buildings := selection_manager.get_selected_buildings_on_team()
	var manufacturing_components: Array[ManufacturingComponent]
	for building in buildings:
		var comp:ManufacturingComponent = Components.get_component(Components.Manufacturing, building)
		if comp:
			manufacturing_components.push_back(comp)
	
	manufacturing_components.sort_custom(func(a:ManufacturingComponent, b:ManufacturingComponent) -> bool:
		return a.available_build_slots > b.available_build_slots
	)
	
	for comp in manufacturing_components:
		if comp.can_build(type):
			@warning_ignore("missing_await")
			comp.build(type)
			break
