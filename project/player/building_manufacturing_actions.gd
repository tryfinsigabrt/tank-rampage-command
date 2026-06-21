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
		
	# TODO: Can map these via config resource rather than hardcoded constants
	if event.is_action_pressed("cancel_marine"):
		_dispatch_cancel_build_marine()
	elif event.is_action_pressed("build_marine"):
		_dispatch_build_marine()
	
	elif event.is_action_pressed("cancel_tank"):
		_dispatch_cancel_build_tank()
	elif event.is_action_pressed("build_tank"):
		_dispatch_build_tank()
		
	elif event.is_action_pressed("cancel_artillery"):
		_dispatch_cancel_build_artillery()
	elif event.is_action_pressed("build_artillery"):
		_dispatch_build_artillery()
		
	elif event.is_action_pressed("cancel_transport"):
		_dispatch_cancel_build_transport()
	elif event.is_action_pressed("build_transport"):
		_dispatch_build_transport()
		
	elif event.is_action_pressed("cancel_mines"):
		_dispatch_cancel_build_mines()
	elif event.is_action_pressed("build_mines"):
		_dispatch_build_mines()
		
	elif event.is_action_pressed("cancel_sandbags"):
		_dispatch_cancel_build_sandbags()
	elif event.is_action_pressed("build_sandbags"):
		_dispatch_build_sandbags()
		
	elif event.is_action_pressed("cancel_tank_spikes"):
		_dispatch_cancel_build_tank_spikes()
	elif event.is_action_pressed("build_tank_spikes"):
		_dispatch_build_tank_spikes()

	elif event.is_action_pressed("cancel_bunker"):
		_dispatch_cancel_build_bunker()
	elif event.is_action_pressed("build_bunker"):
		_dispatch_build_bunker()
	
	elif event.is_action_pressed("cancel_turret"):
		_dispatch_cancel_build_turret()
	elif event.is_action_pressed("build_turret"):
		_dispatch_build_turret()
		
#region Build Types	
func _dispatch_build_marine() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Marine)
	
func _dispatch_build_tank() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Tank)
	
func _dispatch_build_artillery() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Artillery)

func _dispatch_build_transport() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Transport)
	
func _dispatch_build_mines() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Mine)

func _dispatch_build_sandbags() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.BarbedWire)
	
func _dispatch_build_tank_spikes() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.TankSpikes)
		
func _dispatch_build_bunker() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Bunker)

func _dispatch_build_turret() -> void:
	_dispatch_viable_build_order(ConstructionResource.Type.Turret)
	
func _dispatch_cancel_build_marine() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Marine)

func _dispatch_cancel_build_tank() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Tank)

func _dispatch_cancel_build_artillery() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Artillery)

func _dispatch_cancel_build_transport() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Transport)
	
func _dispatch_cancel_build_mines() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Mine)

func _dispatch_cancel_build_sandbags() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.BarbedWire)
	
func _dispatch_cancel_build_tank_spikes() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.TankSpikes)
	
func _dispatch_cancel_build_bunker() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Bunker)

func _dispatch_cancel_build_turret() -> void:
	_dispatch_viable_build_cancel_order(ConstructionResource.Type.Turret)
	
#endregion

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

func _dispatch_viable_build_cancel_order(type: ConstructionResource.Type) -> void:
	var buildings := selection_manager.get_selected_buildings_on_team()
	var manufacturing_components: Array[ManufacturingComponent]
	for building in buildings:
		var comp:ManufacturingComponent = Components.get_component(Components.Manufacturing, building)
		if comp:
			manufacturing_components.push_back(comp)
	
	# Sort in reverse to find most occupied manufacturing
	manufacturing_components.sort_custom(func(a:ManufacturingComponent, b:ManufacturingComponent) -> bool:
		return a.available_build_slots < b.available_build_slots
	)
	
	for comp in manufacturing_components:
		if not comp.can_be_canceled :
			continue
		var cancelable: Array[ManufacturingComponent.BuildQueueElement] = comp.cancelable_builds
		var item_to_cancel:ManufacturingComponent.BuildQueueElement = null
		# Cancel from the end
		for i in range(cancelable.size() - 1, -1, -1):
			var elm := cancelable[i]
			if elm.resource.type == type:
				item_to_cancel = elm
				break
		if item_to_cancel:
			comp.cancel_single_build(item_to_cancel)
