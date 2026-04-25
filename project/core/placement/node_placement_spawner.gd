class_name NodePlacementSpawner extends Node3D

@export
var resource:NodePlacementSpawnerResource

@export
var match_team:MatchTeam

@export
var above_ground_height:float = 50.0

@onready var asset_container: Node3D = $AssetContainer

# Will project the "corners" of the object to ground and then sample to see the slope
@onready var ground_picker: NodePicker = $GroundPicker
@onready var viable_placement_effect: AssetSelectionEffect = %ViablePlacementEffect
@onready var not_viable_placement_effect: AssetSelectionEffect = %NotViablePlacementEffect

var _can_spawn:bool = false
var _ghost_asset:StaticBody3D

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
	if not _ghost_asset:
		push_error("%s: Could not spawn scene=%s as StaticBody3D!" % [name, resource.to_spawn.resource_path])
		return
		
	_ghost_asset.visible = false
	_ghost_asset.position = Vector3.UP * above_ground_height
	asset_container.add_child(_ghost_asset)
	
	_world_boundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries) as WorldBoundaries
	
	_find_collision_shape()
		
func activate() -> void:
	if _ghost_asset.visible:
		return
		
	_ghost_asset.visible = true
	_can_spawn = false
	
func deactivate() -> void:
	if not _ghost_asset.visible:
		return
	
	_ghost_asset.visible = false
	_can_spawn = false
	
func move_to(pos:Vector3) -> void:
	# Initially translate ghost in xz plane
	var curr_ghost := _ghost_asset.global_position
	curr_ghost.x = pos.x
	curr_ghost.z = pos.z
	_ghost_asset.global_position = curr_ghost
	
	_update_eligibility(pos)
	
func spawn(asset_name:StringName="") -> Node3D:
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
		
	asset.global_rotation_degrees = _spawn_rotation_euler
	asset.global_position = _spawn_position
	
	var existing_parent:Node = asset.get_parent()
	if existing_parent:
		existing_parent.remove_child(asset)
			
	if match_team:
		var team_assigned:bool = false
		if "team" in asset:
			asset.team = match_team.team
			team_assigned = true
		match_team.add_child(asset)
		if not team_assigned:
			var team_component:TeamComponent = TeamComponent.get_component(asset, false)
			if team_component:
				team_component.team = match_team.team
	else:
		asset_container.add_child(asset)
		
	deactivate()
	return true
	
func _update_eligibility(pos:Vector3) -> void:
	var ground_position:Vector3 = ground_picker.project_to_ground(pos)
	if ground_position == Vector3.INF:
		_can_spawn = false
		return
	# Move ghost to be above the current ground position
	_ghost_asset.global_position.y = ground_position.y + above_ground_height
		
	_can_spawn = _test_position_for_collisions(ground_position)
	if not _can_spawn:
		return
		
	_can_spawn = _is_viable_ground(ground_position)
	if not _can_spawn:
		return
		
	_spawn_position = ground_position

func _is_viable_ground(_pos:Vector3) -> bool:
	# TODO: Test slope and make sure ground is available on all points
	# Also make sure not outside world bounds
	_spawn_rotation_euler = Vector3.ZERO
	return true
	
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
	_collision_shape = collision.polygon
		
func _test_position_for_collisions(pos: Vector3) -> bool:
	if not _collision_shape:
		return true
		
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = _ghost_asset.collision_mask
	params.margin = resource.collision_mask
	params.transform = Transform3D(Basis.IDENTITY, pos)
	params.shape = _collision_shape
	
	var space_state := get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params)
	
	return not results
