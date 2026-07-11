class_name UnitSweeper extends Node

const MAX_ASSET_RESULT_COUNT:int = 256

@export
var vision_radius:float = 100.0:
	set(value):
		if vision_radius != value and _sweep_rid:
			vision_radius = value
			_update_sweep_shape(_sweep_rid)
		

@export_flags_3d_physics
var collision_mask:int = Collisions.CompositeMasks.team_asset

@export
var enemy_mode:bool = true

var _sweep_rid:RID

func _ready() -> void:
	_sweep_rid = _create_sweep_shape()
	
func _exit_tree() -> void:
	if _sweep_rid:
		PhysicsServer3D.free_rid(_sweep_rid)
		_sweep_rid = RID()
		
func _create_sweep_shape() -> RID:
	var shape_rid := PhysicsServer3D.sphere_shape_create()
	_update_sweep_shape(shape_rid)
	
	return shape_rid

func _update_sweep_shape(rid:RID) -> void:
	PhysicsServer3D.shape_set_data(rid, vision_radius)
	
## Sweep for assets for indicated center point, excluding passed units, and optionally checking if visible to team if > 0
## Also excludes assets that are on team if team > 0
func sweep_assets(center:Vector3, exclude:Array, team:int) -> Array[Node3D]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, center)
	# Exclude given assets
	params.exclude = _to_rids(exclude)
	params.shape_rid = _sweep_rid
	
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
			if team_component:
				if enemy_mode:
					include = team_component.is_enemy_team(team) and team_component.is_visible_to(team)
				else:
					include = team_component.is_on_team(team)
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
