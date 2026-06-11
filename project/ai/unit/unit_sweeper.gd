class_name UnitSweeper extends Node

const MAX_ASSET_RESULT_COUNT:int = 256

@export
var vision_radius:float = 100.0

@export_flags_3d_physics
var collision_mask:int = Collisions.CompositeMasks.team_asset

var _enemy_sweep_rid:RID

func _ready() -> void:
	_enemy_sweep_rid = _create_sweep_shape()
	
func _exit_tree() -> void:
	if _enemy_sweep_rid:
		PhysicsServer3D.free_rid(_enemy_sweep_rid)
		
func _create_sweep_shape() -> RID:
	var shape_rid := PhysicsServer3D.sphere_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, vision_radius)
	
	return shape_rid
	
## Sweep for assets for indicated center point, excluding passed units, and optionally checking if visible to team if > 0
## Also excludes assets that are on team if team > 0
func sweep_assets(center:Vector3, exclude:Array, team:int) -> Array[Node3D]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, center)
	# Exclude our units
	params.exclude = _to_rids(exclude)
	params.shape_rid = _enemy_sweep_rid
	
	var space_state := get_viewport().world_3d.direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(params, MAX_ASSET_RESULT_COUNT)
	var assets:Array[Node3D]
	
	for result in results:
		var asset:Node3D = result.get("collider") as Node3D
		if not asset or not asset.is_in_group(Groups.TeamAsset):
			continue
		var include:bool = team <= 0
		if not include:
			var team_component := TeamComponent.get_component(asset, false)
			if team_component and team_component.is_enemy_team(team) and team_component.is_visible_to(team):
				include = true
		if include and not asset in assets:
			assets.push_back(asset)
	
	return assets

static func _to_rids(nodes:Array) -> Array[RID]:
	var rids:Array[RID]
	rids.resize(nodes.size())
	var cnt:int = 0
	for i in nodes.size():
		var node:CollisionObject3D = nodes[i] as CollisionObject3D
		if node:
			rids[cnt] = node.get_rid()
			cnt += 1
	rids.resize(cnt)
	return rids
