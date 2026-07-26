class_name HumanArtilleryUnit extends Unit

@export
var turning_speed_degrees: float = 45.0

@export
var aiming_speed_degrees:float = 20.0

@export
var aim_turning_speed_degrees: float = 90.0

@export
var delta_aim_threshold_degrees:float = 1.0

@export
var pos_dist_sq_reaim_threshold:float = 1.0

## Rotation angle to put on turret vs the max firing distance fraction
@export
var rotation_angle_v_distance_fraction:Curve

## Set to true if mesh +Z faces the target instead of -Z
@export
var use_model_front:bool = false

@export
var move_aim_reset_delay_seconds:float = 60.0

@onready var collision: CollisionShape3D = %Collision
@onready var visual_root: Node3D = %VisualRoot
@onready var health_stat: HealthStat = %HealthStat
@onready var weapon_trace: Marker3D = %WeaponTrace
@onready var _weapon: Weapon = %Weapon
@onready var ui: Node3D = %UI
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation
@onready var _team_comp: TeamComponent = %TeamComponent
@onready var yaw_pitch_aiming_component: YawPitchAimingComponent = %YawPitchAimingComponent
@onready var _tank_shadow: Node3D = $TankShadow

@export
var turret_rotation_node:Node3D

@export
var barrel_pitch_node:Node3D

var _has_moved:bool

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
		
## Provides the screen direction to instruct the unit to move to
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if input_direction.is_zero_approx():
		return
		
	_has_moved = true
	
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(turning_speed_degrees) * get_physics_process_delta_time() * rotation_dir
	
	# Rotate the whole character so that the collider rotates too
	rotate_y(rot)

	var speed:float = movement_speed if speed_override <= 0.0 else speed_override
	var movement_direction := -input_direction_3.z * global_forward
	var projected_movement:Vector2 = Vector2(movement_direction.x, movement_direction.z).normalized()
	
	if projected_movement:
		velocity.x = projected_movement.x * speed
		velocity.z = projected_movement.y * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Reset any turret raw so we are pointing forward
	yaw_pitch_aiming_component.reset_turret_yaw()
	
	move_and_slide()

func aim_at(world_location:Vector3) -> void:
	yaw_pitch_aiming_component.aim_at(weapon, world_location)

func shoot() -> void:
	await _weapon.fire()

func get_fire_global_position() -> Vector3:
	return weapon_trace.global_position
	
func _get_fire_alignment_basis() -> Basis:
	var reference_up := global_basis.y.normalized()
	# Turret is rotated 180 due to parent visual_root so negate the basis vector +Z is model forward
	var fire_forward := (turret_rotation_node.global_basis.z).slide(reference_up).normalized()

	# Right-handed frame: right = forward x up
	var fire_right := fire_forward.cross(reference_up).normalized()

	# Recompute up so the basis is orthonormal
	var fire_up := fire_right.cross(fire_forward).normalized()

	var basis_forward:Vector3 = fire_forward if not use_model_front else -fire_forward
	return Basis(fire_right, fire_up, basis_forward)

func get_fire_global_forward() -> Vector3:
	return -_get_fire_alignment_basis().z

func get_fire_global_right() -> Vector3:
	return _get_fire_alignment_basis().x

func get_fire_global_up() -> Vector3:
	return _get_fire_alignment_basis().y

func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	died.emit(damage_params)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _on_took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		_die(damage_params)

func _update_render(in_render:bool) -> void:
	visual_root.visible = in_render
	ui.visible = in_render
	_tank_shadow.visible = in_render

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon

func _get_team_component() -> TeamComponent:
	return _team_comp
