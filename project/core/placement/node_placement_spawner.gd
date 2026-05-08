class_name NodePlacementSpawner extends Node3D

signal on_spawn(asset:Node3D)

@export
var resource:NodePlacementSpawnerResource

@export
var match_team:MatchTeam

@export
var above_ground_height:float = 50.0

@export
var fow_visibility_threshold:float = 0.1

@onready var asset_container: Node3D = $AssetContainer

# Will project the "corners" of the object to ground and then sample to see the slope
@onready var ground_picker: NodePicker = $GroundPicker
@onready var viable_placement_effect: AssetSelectionEffect = %ViablePlacementEffect
@onready var not_viable_placement_effect: AssetSelectionEffect = %NotViablePlacementEffect

var _can_spawn:bool = false
var _ghost_asset:StaticBody3D
var _asset_aabb:AABB

var _spawn_rotation_euler:Vector3
var _spawn_position:Vector3

var _collision_shape:Resource
var _world_boundaries:WorldBoundaries

var can_spawn:bool:
	get:
		return _can_spawn

func _ready() -> void:
	if not match_team:
		match_team = GameManager.find_match_team(self)
	if not match_team:
		push_warning("%s: No match team found - will not be to assign spawned asset sto team")
		
	if not resource:
		assert("%s: No resource assigned" % name)
		return
	
	if not resource.to_spawn:
		assert("%s: to_spawn not set on resource!" % name)
		return
		
	_ghost_asset = resource.to_spawn.instantiate() as StaticBody3D
	_ghost_asset.collision_mask = 0
	_ghost_asset.collision_layer = 0

	if not _ghost_asset:
		push_error("%s: Could not spawn scene=%s as StaticBody3D!" % [name, resource.to_spawn.resource_path])
		return
		
	_ghost_asset.visible = false
	_ghost_asset.position = Vector3.UP * above_ground_height
	asset_container.add_child(_ghost_asset)
	
	_world_boundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries) as WorldBoundaries
	
	_find_collision_shape()
	
	_asset_aabb = _ghost_asset.get_bounds() if _ghost_asset.has_method("get_bounds") else Collisions.calculate_aabb(_ghost_asset)
		
func activate() -> void:
	if _ghost_asset.visible:
		return
		
	_ghost_asset.visible = true
	_can_spawn = false
	_update_effects()
	
func deactivate() -> void:
	if not _ghost_asset.visible:
		return
	
	_ghost_asset.visible = false
	_can_spawn = false
	
func move_to(pos:Vector3, is_grounded:bool = false) -> void:
	# Initially translate ghost in xz plane
	var curr_ghost := _ghost_asset.global_position
	curr_ghost.x = pos.x
	curr_ghost.z = pos.z
	_ghost_asset.global_position = curr_ghost
	
	_update_state(pos, is_grounded)

func _update_state(pos:Vector3, is_grounded:bool) -> void:
	_update_eligibility(pos, is_grounded)
	_update_effects()
	
func _refresh_state() -> void:
	var pos:Vector3 = _ghost_asset.global_position
	pos.y -= above_ground_height
	
	_update_state(pos, false)
	
func spawn(asset_name:StringName="") -> Node3D:
	if not _ghost_asset.visible:
		push_error("%s: Attempted to spawn asset=%s:%s when inactive!" % [name, asset_name, _ghost_asset.name])
		return null
		
	_refresh_state()
	if not _can_spawn:
		return null
	
	var asset:Node3D = resource.to_spawn.instantiate()
	if asset_name:
		asset.name = asset_name
		
	place(asset)
	
	return asset

##Instead of spawning, attempts to place the given asset
func place(asset:StaticBody3D) -> bool:
	if not _can_spawn:
		return false
	
	var existing_parent:Node = asset.get_parent()
	if existing_parent:
		existing_parent.remove_child(asset)
			
	if match_team:
		match_team.assign_to_team(asset)
	else:
		asset_container.add_child(asset)
	
	asset.global_rotation_degrees = _spawn_rotation_euler
	asset.global_position = _spawn_position
	
	on_spawn.emit(asset)
		
	deactivate()
	return true
	
func _update_eligibility(pos:Vector3, is_grounded:bool) -> void:
	var ground_position:Vector3
	if is_grounded:
		_can_spawn = true
		ground_position = pos
	else:
		ground_position = ground_picker.project_to_ground(pos)
		if ground_position == Vector3.INF:
			_can_spawn = false
			return
	# Move ghost to be above the current ground position
	_ghost_asset.global_position = Vector3(ground_position.x, ground_position.y + above_ground_height, ground_position.z)
	
	_can_spawn = _test_position_for_collisions(ground_position)
	if not _can_spawn:
		return
		
	if _world_boundaries and not _world_boundaries.contains_body(_ghost_asset):
		_can_spawn = false
		return
		
	# Check visibility if in fow
	var fow: FogOfWar = GameManager.fog_of_war_node
	if fow and GameManager.fog_of_war and not fow.is_node_visible(_ghost_asset, fow_visibility_threshold, FogOfWar.FOW_VISIBLE_CHANNEL, true):
		_can_spawn = false
		return
		
	_can_spawn = _is_viable_ground(ground_position)
	if not _can_spawn:
		return
		
	_spawn_position = ground_position

func _update_effects() -> void:
	if not _ghost_asset.is_visible_in_tree():
		return
		
	if _can_spawn:	
		not_viable_placement_effect.toggle_selection(_ghost_asset, false)
		viable_placement_effect.toggle_selection(_ghost_asset, true)
	else:
		viable_placement_effect.toggle_selection(_ghost_asset, false)
		not_viable_placement_effect.toggle_selection(_ghost_asset, true)
			
func _is_viable_ground(pos:Vector3) -> bool:
	# TODO: Would need to combine this with any existing yaw rotation requested by user in the 
	_spawn_rotation_euler = Vector3.ZERO
	if not _asset_aabb.has_volume():
		return true
	
	# Move so centered on requested position
	_asset_aabb.position = pos - _asset_aabb.size * 0.5
	
	# Use the bottom points
	var planar_points:PackedVector3Array = [	
		_asset_aabb.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_LEFT),
		_asset_aabb.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_RIGHT),
		_asset_aabb.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_LEFT),
		_asset_aabb.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_RIGHT)
	]
	
	# Check the ground offset at the given points
	for i in planar_points.size():
		var point:Vector3 = planar_points[i]
		var grounded_point:Vector3 = ground_picker.project_to_ground(point)
		if grounded_point == Vector3.INF:
			return false
		planar_points[i] = grounded_point
	
	var ground_normal := _get_avg_normal(planar_points)
	
	var angle_to_up := absf(rad_to_deg(ground_normal.angle_to(Vector3.UP)))
	if angle_to_up > resource.max_slope_angle_deg:
		return false
		
	_spawn_rotation_euler = _get_alignment_quaternion(_ghost_asset.global_transform, ground_normal).get_euler()
	
	return true
	
func _get_avg_normal(planar_points:PackedVector3Array) -> Vector3:
	# Diagonal 1: Front Left to Back Right
	var diag1 := planar_points[3] - planar_points[0]
	# Diagonal 2: Front Right to Back Left
	var diag2 := planar_points[2] - planar_points[1]

	# This cross product averages the 'twist' of the terrain
	# Make sure it points up
	var ground_normal := diag2.cross(diag1).normalized()
	
	if ground_normal.y < 0:
		ground_normal = -ground_normal
		
	return ground_normal
	
static func _get_alignment_quaternion(current_transform: Transform3D, target_normal: Vector3) -> Quaternion:
	var current_up := current_transform.basis.y
	# Find the shortest rotation from current UP to ground NORMAL
	return Quaternion(current_up, target_normal)
	
func _find_collision_shape() -> void:
	var collision_nodes := Collisions.get_collisions_nodes(_ghost_asset)
	# Only support first collision shape
	if not collision_nodes:
		push_warning("%s: Asset=%s has no collision!" % [name, _ghost_asset.scene_file_path])
		return
	var collision:CollisionShape3D = collision_nodes.filter(func(node:Node) -> bool: return node is CollisionShape3D).front()
	if not collision:
		push_warning("%s: Asset=%s does not have a CollisionShape3D - found %s" % [name, _ghost_asset.scene_file_path, collision_nodes])
		return
	_collision_shape = collision.shape
		
func _test_position_for_collisions(pos: Vector3) -> bool:
	if not _collision_shape:
		return true
		
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = resource.collision_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.shape = _collision_shape
	
	var space_state := get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params, 1)
	
	return not results
