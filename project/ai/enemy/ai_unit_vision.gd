## Visibility scanner for AI to replicate the fog of war vision system
## This is only added if fow enabled
class_name AiUnitVision extends Area3D

var _team_component:TeamComponent
var _team_visibility_component:TeamVisibilityComponent

@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	var node: Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if not node:
		push_error("%s: Unit vision not added to a team asset hierarchy: " % name)
		queue_free()
		return
	_team_component = Components.get_component(Components.Team, node)
	if not _team_component:
		push_error("%s: Unit vision asset %s has no team_component getter!" % [name, node.name])
		queue_free()
		return
	
	var match_obj:MatchTeam = GameManager.find_match_team(node)
	if not match_obj:
		push_error("%s: Unit vision asset %s is not part of a match team!" % [name, node.name])
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

func _on_body_entered(body: Node3D) -> void:
	_update_visibility(body, true)
	
func _on_body_exited(body: Node3D) -> void:
	_update_visibility(body, false)

func _update_visibility(body: Node3D, in_visible:bool) -> void:
	var team_asset:Node3D = body as Node3D if body.is_in_group(Groups.TeamAsset) else null
	if not team_asset:
		return
	
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
