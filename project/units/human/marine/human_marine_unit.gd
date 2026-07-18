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
@onready var fire_position: Marker3D = %FireOrigin
@onready var _weapon: Weapon = %Weapon
@onready var game_unit_navigation: GameUnitNavigation = %GameUnitNavigation
@onready var animation: MarineAnimation = %MarineAnimation
@onready var mesh: MeshInstance3D = $VisualRoot/Armature/Skeleton3D/BaseMarine
@onready var ui: Node3D = %UI
@onready var _team_comp: TeamComponent = %TeamComponent

var _aim_at_tween:Tween
var _has_moved:bool
var _last_target_aim:Quaternion
var _aim_target:Vector3 = Vector3.INF
var _visual_root_rest_transform:Transform3D
var _fire_origin_rest_transform:Transform3D
var _ground_basis:Basis

var _ground_cast_parameters:PhysicsRayQueryParameters3D
var _surface_normal:Vector3
var _elapsed_since_cast:float = 0.0

@export
var ground_cast_interval:float = 0.2

@export_range(0.0, 89.0, 0.1)
var max_aim_pitch_degrees:float = 25.0

func _set_visual_overrides(_overrides:AssetVisualTeamResource) -> void:
	_set_mesh_material()
	
func _ready() -> void:
	super._ready()
	_visual_root_rest_transform = visual_root.transform
	_fire_origin_rest_transform = fire_position.transform
	_ground_basis = global_basis
	
	_ground_cast_parameters = PhysicsRayQueryParameters3D.new()
	_ground_cast_parameters.collision_mask = Collisions.CompositeMasks.ground
	_ground_cast_parameters.collide_with_areas = false
	_ground_cast_parameters.collide_with_bodies = true
	
	_set_mesh_material()
	
func _set_mesh_material() -> void:
	if not (team_resource is MarineTeamResource) or not team_resource.material or not mesh:
		return
	
	var material_to_set:Material = team_resource.material
	mesh.set_surface_override_material(0, material_to_set)
	
func _is_alive() -> bool:
	return health_stat.is_alive

func _physics_process(delta: float) -> void:
	collision.disabled = not _is_alive() or not is_visible_in_tree()

	# Add the gravity.
	# Weird issue where if unit hasn't moved it reports not on floor
	if is_on_floor() or not _has_moved:
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta

	if _is_alive():
		_upright_body_when_stationary()
		_reorient_along_surface_normal(delta)

# TODO: Some of this can be moved to unit base class or separate component
func move(input_direction:Vector2, speed_override:float = -1.0) -> void:
	if is_dead or input_direction.is_zero_approx():
		return
	
	_has_moved = true
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
	_aim_target = world_location
	_update_fire_origin_basis()

	var flat_target := Vector3(world_location.x, global_position.y, world_location.z)
	if Vector2(flat_target.x - global_position.x, flat_target.z - global_position.z).is_zero_approx():
		return

	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_transform := global_transform.looking_at(flat_target, Vector3.UP)
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
		if _aim_at_tween.is_running() and target_quat.is_equal_approx(_last_target_aim):
			return
		_aim_at_tween.kill()
		_aim_at_tween = null

	var parent := get_parent_node_3d()
	var target_local_quat := target_quat if not parent else parent.global_basis.get_rotation_quaternion().inverse() * target_quat

	var tween := create_tween()
	tween.tween_property(self, "quaternion", target_local_quat, duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
	
	_aim_at_tween = tween
	_last_target_aim = target_quat
	
func shoot() -> void:	
	await _weapon.fire()

func get_fire_global_position() -> Vector3:
	return fire_position.global_position

# For the directions use the marine forward because these are used for LOS and gun isn't always at "ready" position	
func get_fire_global_forward() -> Vector3:
	return -_get_fire_aim_basis().z

func get_fire_global_right() -> Vector3:
	return _get_fire_aim_basis().x

func get_fire_global_up() -> Vector3:
	return _get_fire_aim_basis().y
	
func _is_moving() -> bool:
	return game_unit_navigation.enabled

func _update_render(in_render:bool) -> void:
	visual_root.visible = in_render
	ui.visible = in_render

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
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(damage_params: DamageParameters) -> void:
	damaged.emit(damage_params)
	if health_stat.is_dead:
		@warning_ignore("missing_await")
		_die(damage_params)

func _get_health_stat() -> HealthStat:
	return health_stat

func _get_weapon() -> Weapon:
	return _weapon

func _on_weapon_firing_state_changed(firing: bool) -> void:
	#print("%s: SHOOTING=%s" % [name, firing])
	_is_shooting = firing and is_alive

func _upright_body_when_stationary() -> void:
	if not Vector2(velocity.x, velocity.z).is_zero_approx() or is_instance_valid(_aim_at_tween) and _aim_at_tween.is_running():
		return
	if global_up.is_equal_approx(Vector3.UP):
		return
	global_basis = _basis_from_forward_and_up(global_forward, Vector3.UP)

func _reorient_along_surface_normal(delta:float) -> void:
	var space_state := get_world_3d().direct_space_state
	
	var current_pos:Vector3 = global_position
	
	_elapsed_since_cast += delta
	if not _surface_normal or _elapsed_since_cast >= ground_cast_interval:
		_ground_cast_parameters.from = current_pos + Vector3.UP * 100.0
		_ground_cast_parameters.to = current_pos + Vector3.DOWN * 100.0
		
		var result := space_state.intersect_ray(_ground_cast_parameters)
		if result:
			_surface_normal = result["normal"].normalized()
		else:
			_surface_normal = Vector3.ZERO
		_elapsed_since_cast = 0.0
		
	var surface_up := _surface_normal if _surface_normal else Vector3.UP
	_ground_basis = _basis_from_forward_and_up(global_forward, surface_up)
	var ground_transform := Transform3D(_ground_basis, global_position)
	visual_root.global_transform = ground_transform * _visual_root_rest_transform
	fire_position.global_transform = ground_transform * _fire_origin_rest_transform
	_update_fire_origin_basis()

func _update_fire_origin_basis() -> void:
	fire_position.global_basis = _get_fire_aim_basis() * _fire_origin_rest_transform.basis

func _get_fire_aim_basis() -> Basis:
	var ground_up := _ground_basis.y.normalized()
	var fire_forward := -_ground_basis.z
	if _aim_target.is_finite():
		var target_direction := fire_position.global_position.direction_to(_aim_target)
		var target_pitch := asin(clampf(target_direction.dot(ground_up), -1.0, 1.0))
		var max_pitch := deg_to_rad(max_aim_pitch_degrees)
		var pitch := clampf(target_pitch, -max_pitch, max_pitch)
		fire_forward = (fire_forward * cos(pitch) + ground_up * sin(pitch)).normalized()

	var fire_right := fire_forward.cross(ground_up).normalized()
	var fire_up := fire_right.cross(fire_forward).normalized()
	return Basis(fire_right, fire_up, -fire_forward)

func _basis_from_forward_and_up(forward_hint:Vector3, up_vector:Vector3) -> Basis:
	if up_vector.is_zero_approx():
		return global_basis

	var new_forward := forward_hint.slide(up_vector)
	if new_forward.is_zero_approx():
		var planar := Vector3.FORWARD if absf(up_vector.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		new_forward = planar.slide(up_vector)
		if new_forward.is_zero_approx():
			return global_basis
	new_forward = new_forward.normalized()

	var new_right := new_forward.cross(up_vector).normalized()
	new_forward = up_vector.cross(new_right).normalized()
	return Basis(new_right, up_vector, -new_forward)
	
func _get_team_component() -> TeamComponent:
	return _team_comp
