class_name HumanMarineUnit extends Unit

@export_range(1.0,360.0, 0.1)
var turning_speed_degrees:float = 180.0

var _is_shooting:bool

var is_shooting:bool:
	get:
		return _is_shooting
		
@onready var health_stat: HealthStat = %HealthStat
@onready var collision: CollisionShape3D = %Collision
@onready var visual_root: Node3D = %VisualRoot
@onready var fire_position: Marker3D = %FirePosition
@onready var _weapon: Weapon = %Weapon
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation
@onready var animation: MarineAnimation = %MarineAnimation
@onready var mesh: MeshInstance3D = $VisualRoot/Armature/Skeleton3D/BaseMarine
@onready var ui: Node3D = %UI

@export
var team_resource:MarineTeamResource:
	set(value):
		team_resource = value
		_set_mesh_material()

var _aim_at_tween:Tween

func _ready() -> void:
	super._ready()
	_set_mesh_material()
	
func _set_mesh_material() -> void:
	if not team_resource or not team_resource.material or not mesh:
		return
	
	var material_to_set:Material = team_resource.material
	mesh.set_surface_override_material(0, material_to_set)
	
func _is_alive() -> bool:
	return health_stat.is_alive

func _physics_process(delta: float) -> void:
	collision.disabled = not _is_alive() or not is_visible_in_tree()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

# TODO: Some of this can be moved to unit base class or separate component
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if is_dead or input_direction.is_zero_approx():
		return
	
	# Move forward/back always proceeds along forward vector 
	# and left/right rotates in place
	var input_direction_3:Vector3 = Vector3(input_direction.x, 0.0, input_direction.y)
	
	# Positive rotation is ccw but we want right (+x) to turn model cw so negate
	var rotation_dir:float = signf(-input_direction.x)
	var rot:float = deg_to_rad(turning_speed_degrees) * get_physics_process_delta_time() * rotation_dir
	
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
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_transform := global_transform.looking_at(world_location, global_up)
	var target_quat := target_transform.basis.get_rotation_quaternion()

	# Calculate the angle between current quat and target rotation quat
	var angle_rad := current_quat.angle_to(target_quat)
	var angle_deg := rad_to_deg(angle_rad)
	
	# Calculate duration (Time = Angular Distance / Speed)
	# Avoid division by zero if already looking at the target
	if angle_deg < 0.01: 
		return 
		
	var duration := angle_deg / turning_speed_degrees
		
	if is_instance_valid(_aim_at_tween):
		_aim_at_tween.kill()
		_aim_at_tween = null

	var tween := create_tween()
	tween.tween_property(self, "quaternion", target_quat, duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	
	_aim_at_tween = tween
	
func shoot() -> void:
	_weapon.fire()
	
	# TODO: We should have a blended animation so enemy can shoot while moving
	# This can probably be done in the animation tree blend space
	SignalBus.on_unit_move_canceled.emit(self, game_unit_navigation.current_target)

func get_fire_global_position() -> Vector3:
	return fire_position.global_position

# For the directions use the marine forward because these are used for LOS and gun isn't always at "ready" position	
func get_fire_global_forward() -> Vector3:
	## Positive as we rotated around
	#var orig_basis:Basis = fire_position.global_basis
	#var corrected_basis:Basis = visual_root.transform.basis
	#var final_basis:Basis = orig_basis * corrected_basis
	#return -final_basis.z
	return global_forward

func get_fire_global_right() -> Vector3:
	#return fire_position.global_basis.x
	return global_right

func get_fire_global_up() -> Vector3:
	#return fire_position.global_basis.y
	return global_up
	
func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _update_render() -> void:
	visual_root.visible = render
	ui.visible = render

func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	collision.disabled = true
	velocity = Vector3.ZERO
	_is_shooting = false
	set_physics_process(false)
	
	died.emit(damage_params)
	
	# Delay so can see visuals
	# TODO: Get animation notification when complete
	await get_tree().create_timer(2.0).timeout
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		_die(damage_params)

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon

func _on_weapon_firing_state_changed(firing: bool) -> void:
	#print("%s: SHOOTING=%s" % [name, firing])
	_is_shooting = firing and is_alive
