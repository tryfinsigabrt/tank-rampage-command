class_name BunkerStructure extends DefensiveStructure

@onready var _unit_container_component: UnitContainerComponent = %UnitContainerComponent
@onready var _node_viable_position_finder: NodeViablePositionFinder = %NodeViablePositionFinder
@onready var targeting_component: WeaponTargetingComponent = %WeaponTargetingComponent
@onready var position_distributor: PositionDistributor = %PositionDistributor

@export
var weapon_attributes:WeaponAttributeMods

var _destroyed:bool

var _position_offsets_by_unit_id:Dictionary[int,Vector3]
	
func _do_update_render(in_visible:bool) -> void:
	visible = in_visible

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

func _add_to_bunker_defense(unit: Unit) -> void:
	targeting_component.add_weapon(unit.get_instance_id(), unit.weapon, true)
	
func _remove_from_bunker_defense(unit: Unit) -> void:
	targeting_component.remove_weapon(unit.get_instance_id())
	
	# Wait a frame so that physics toggle takes effect
	await get_tree().physics_frame
	
	var offset_position:Vector3 = _position_offsets_by_unit_id.get(unit.get_instance_id(), Vector3.ZERO)
	if _destroyed:
		# Just place the unit at the bunker's global position
		var location:Vector3 = global_position + offset_position
		# Face the forward direction of the bunker
		var direction:Vector3 = -global_basis.z
		_node_viable_position_finder.attempt_placement_at(location, direction, unit, true)
	else:
		_node_viable_position_finder.place_asset(unit, offset_position)
	
func _on_unit_removed(unit: Unit) -> void:
	await _remove_from_bunker_defense(unit)

func _on_weapon_setup(weapon: Weapon) -> void:
	if not weapon_attributes:
		return
	weapon.max_distance_range *= weapon_attributes.range_bonus


func _on_unit_container_component_on_unit_removal_requested(units: Array[Unit]) -> void:
	_position_offsets_by_unit_id.clear()
	if units.size() <= 1:
		return
	
	# Calculate the offsets from the final desired position
	var exit_position := global_position
	for unit in units:
		unit.global_position = exit_position
	var position_distribution := position_distributor.calculate(units, exit_position)
	for unit in units:
		var unit_id:int = unit.get_instance_id()
		var unit_exit_position := position_distribution[unit_id]
		_position_offsets_by_unit_id[unit_id] = unit_exit_position - exit_position
