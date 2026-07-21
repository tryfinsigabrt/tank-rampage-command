class_name MarineTransportUnit extends Unit

@onready var _unit_container_component: UnitContainerComponent = %UnitContainerComponent
@onready var _node_viable_position_finder: NodeViablePositionFinder = %NodeViablePositionFinder
@onready var model_root: Node3D = %"transport-truck"
@onready var collision: CollisionShape3D = $Collision
@onready var game_unit_navigation: GameUnitNavigation = $GameUnitNavigation
@onready var health_stat: HealthStat = %HealthStat
@onready var ui: Node3D = %UI
@onready var _team_comp: TeamComponent = %TeamComponent
@onready var position_distributor: PositionDistributor = %PositionDistributor

## Position relative to the container unit that inner units will move to upon exit.
@export
var exit_position_delta: Vector3 = Vector3(0, 0, 7) # +Z ends up behind container unit

var _has_moved:bool
var _destroyed: bool = false

func _is_alive() -> bool:
	return health_stat.is_alive
	
func _physics_process(delta: float) -> void:
	collision.disabled = not is_visible_in_tree()

	# Add the gravity.
	# Weird issue where if unit hasn't moved it reports not on floor
	if is_on_floor() or not _has_moved:
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if input_direction.is_zero_approx():
		return
	
	_has_moved = true
	
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(120.0) * get_physics_process_delta_time() * rotation_dir
	
	# Rotate the whole character so that the collider rotates too
	rotate_y(rot)

	var speed:float = movement_speed if speed_override <= 0.0 else speed_override
	# Negative as "forward" is -z as we are using right-handed OpenGL-style coordinate system
	var movement_direction := -input_direction_3.z * global_forward
	var projected_movement:Vector2 = Vector2(movement_direction.x, movement_direction.z).normalized()
	
	if projected_movement:
		velocity.x = projected_movement.x * speed
		velocity.z = projected_movement.y * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func aim_at(world_location:Vector3) -> void:	
	pass

func shoot() -> void:
	pass
	
func get_fire_global_position() -> Vector3:
	return global_position
	
func get_fire_global_forward() -> Vector3:
	return -global_basis.z

func get_fire_global_right() -> Vector3:
	return global_basis.x

func get_fire_global_up() -> Vector3:
	return global_basis.y
	
func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	_destroyed = true
	
	#Disable physics so that units can be placed at bunker position
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	_remove_all_units()
	
	died.emit(damage_params)
	queue_free()

func _remove_all_units() -> void:
	_unit_container_component.remove_all_units()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _on_took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)

func _update_render(in_render:bool) -> void:
	visible = in_render

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return null
	#return barrel.weapon

func _get_team_component() -> TeamComponent:
	return _team_comp

func _on_unit_removed(unit: Unit) -> void:
	# Wait a frame so that physics toggle takes effect
	await get_tree().physics_frame
	
	# Just place where the distributor put the unit
	var location:Vector3 = unit.global_position
	# Face in direction of placement
	var direction:Vector3 = global_position.direction_to(location)
	_node_viable_position_finder.attempt_placement_at(location, direction, unit, true)

func _get_exit_position() -> Vector3:
	var asset_transform := global_transform
	var exit_position_transform := asset_transform.translated_local(exit_position_delta)
	return exit_position_transform.origin

func _on_unit_container_component_on_unit_removal_requested(units: Array[Unit]) -> void:
	var exit_position := _get_exit_position()
	var position_distribution := position_distributor.calculate(units, exit_position)
	for unit in units:
		var unit_exit_position := position_distribution[unit.get_instance_id()]
		unit.global_position = unit_exit_position
