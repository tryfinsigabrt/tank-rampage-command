## Visibility scanner for AI to replicate the fog of war vision system
## This is only added if fow enabled
class_name AiUnitVision extends Area3D

const ComponentName:StringName = &"AiUnitVision"

var _team_component:TeamComponent
var _team_visibility_component:TeamVisibilityComponent

var _visible_objects:PackedInt64Array
var _team_asset_root:Node

@onready var collision: CollisionShape3D = $Collision

var units:Array[Unit]:
	get:
		var _units:Array[Unit]
		for id in _visible_objects:
			var unit:Unit = instance_from_id(id) as Unit
			if unit:
				units.push_back(unit)
		return _units

var unit_ids:PackedInt64Array:
	get:
		var ids:PackedInt64Array
		for id in _visible_objects:
			var unit:Unit = instance_from_id(id) as Unit
			if unit:
				ids.push_back(id)
		return ids
		
func _ready() -> void:
	if not _team_asset_root:
		push_error("%s: Unit vision not added to a team asset hierarchy: " % name)
		queue_free()
		return
	_team_component = Components.get_component(Components.Team, _team_asset_root)
	if not _team_component:
		push_error("%s: Unit vision asset %s has no team_component getter!" % [name, _team_asset_root.name])
		queue_free()
		return
	
	var match_obj:MatchTeam = GameManager.find_match_team(_team_asset_root)
	if not match_obj:
		push_error("%s: Unit vision asset %s is not part of a match team!" % [name, _team_asset_root.name])
		queue_free()
		return
		
	await NodeUtils.ensure_ready(match_obj)
	_team_visibility_component = match_obj.team_visibility_component
	
	# Set radius to unit vision radius
	collision.shape.radius = _team_component.vision
	
	# Set mask to look for enemy team nodes and any resources if set
	var enemy_team_mask:int = Collisions.enemy_team_mask(_team_component.team)
	var mask:int = MathUtils.update_mask(collision_mask, Collisions.CompositeMasks.any_asset, enemy_team_mask)
	
	collision_mask = mask

#region Component Registration
static func get_component(node: Node, required:bool = true) -> AiUnitVision:
	return Components.get_component(ComponentName, node, required) as AiUnitVision
		
func _enter_tree() -> void:
	_team_asset_root = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if _team_asset_root:
		Components.add_component(ComponentName, self, _team_asset_root)

func _exit_tree() -> void:
	if _team_asset_root:
		Components.remove_component(ComponentName, self, _team_asset_root)
#endregion

func _on_body_entered(body: Node3D) -> void:
	_update_visibility(body, true)
	
func _on_body_exited(body: Node3D) -> void:
	_update_visibility(body, false)

func _update_visibility(body: Node3D, in_visible:bool) -> void:
	var team_asset:Node3D = body as Node3D if body.is_in_group(Groups.TeamAsset) else null
	if not team_asset:
		return
	
	var asset_id:int = team_asset.get_instance_id()
	if in_visible:
		_visible_objects.push_back(asset_id)
	else:
		_visible_objects.erase(asset_id)
		
	_team_visibility_component.mark_object_visibility(team_asset, in_visible)	

func _on_area_entered(area: Area3D) -> void:
	_on_area_visibility(area, true)

func _on_area_exited(area: Area3D) -> void:
	_on_area_visibility(area, false)
	
func _on_area_visibility(area: Area3D, in_visible:bool) -> void:
	var resource:Node3D = Groups.get_scene_root_if_in_group(area, Groups.GameResource)
	if resource:
		_team_visibility_component.mark_object_visibility(resource, in_visible)
		return
	var control_point:ControlPoint = Groups.get_scene_root_if_in_group(area, Groups.ControlPoint) as ControlPoint
	if control_point:
		_team_visibility_component.mark_object_visibility(control_point, in_visible)
		return
