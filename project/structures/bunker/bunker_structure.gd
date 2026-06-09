class_name BunkerStructure extends DefensiveStructure

@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI
@onready var _unit_container_component: UnitContainerComponent = %UnitContainerComponent
@onready var node_viable_position_finder: NodeViablePositionFinder = %NodeViablePositionFinder

var _destroyed:bool

func _do_update_render(in_visible:bool) -> void:
	visual_root.visible = in_visible
	ui.visible = in_visible

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	
	_destroyed = true
	
	#Disable physics so that units can be placed at bunker position
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	
	_remove_all_units()
	
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass

func _remove_all_units() -> void:
	_unit_container_component.remove_all_units()
		
func _on_unit_added(unit: Unit) -> void:
	_add_to_bunker_defense(unit)

func _add_to_bunker_defense(_unit: Unit) -> void:
	pass
	
func _remove_from_bunker_defense(unit: Unit) -> void:
	if _destroyed:
		# Just place the unit at the bunker's global position
		var location:Vector3 = global_position
		# Face the forward direction of the bunker
		var direction:Vector2 = MathUtils.grid_vector(-global_basis.z)
		node_viable_position_finder.attempt_placement_at(location, direction, unit, true)
	else:
		node_viable_position_finder.place_asset(unit)
	
func _on_unit_removed(unit: Unit) -> void:
	_remove_from_bunker_defense(unit)
	# TODO: Place outside bunker like when the manfacturing component finds an available spot for unit to spawn
	# If bunker was destroyed then just place unit at bunker center position, may need to wait a frame for physics to update
