## Visibility scanner for AI to replicate the fog of war vision system
## This is only added if fow enabled
class_name AiUnitVision extends Area3D

signal asset_visibility_changed(asset:Node3D, in_is_visible:bool)
signal resource_discovered(resource:Node3D)

var _team_component:TeamComponent
var _vision_counts:Dictionary[int,int] = {}
var _discovered_resources:Dictionary[int, bool] = {}

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
	
	# Set radius to unit vision radius
	collision.shape.radius = _team_component.vision
	
	# Set mask to look for enemy team nodes and any resources if set
	var enemy_team_mask:int = Collisions.enemy_team_mask(_team_component.team)
	var mask:int = MathUtils.update_mask(collision_mask, Collisions.CompositeMasks.any_asset, enemy_team_mask)
	
	collision_mask = mask

func _on_body_entered(body: Node3D) -> void:
	_update_visibility(body, 1)
	
func _on_body_exited(body: Node3D) -> void:
	_update_visibility(body, -1)

func _update_visibility(body: Node3D, diff:int) -> void:
	var team_asset:Node3D = body as Node3D if body.is_in_group(Groups.TeamAsset) else null
	if not team_asset:
		return
		
	var id:int = team_asset.get_instance_id()
	var updated_count:int = _vision_counts.get(id, 0) + diff
	if updated_count > 0:
		_vision_counts[id] = updated_count
		# Newly visible
		if updated_count == 1:
			print_debug("%s: body=%s is visible to %s" % [name, body.name, StringUtils.safe_name(Groups.get_scene_root(_team_component))])
			team_asset.team_component.set_visible_to(_team_component.team, true)
			
			asset_visibility_changed.emit(team_asset, true)
	else:
		_vision_counts.erase(id)
		print_debug("%s: body=%s no longer visible to %s" % [name, body.name, StringUtils.safe_name(Groups.get_scene_root(_team_component))])
		
		team_asset.team_component.set_visible_to(_team_component.team, false)
		asset_visibility_changed.emit(team_asset, false)

# Look for resources
func _on_area_entered(area: Area3D) -> void:
	var resource:Node3D = Groups.get_scene_root_if_in_group(area, Groups.GameResource)
	if not resource:
		return
	var resource_id:int = resource.get_instance_id()
	if resource_id in _discovered_resources:
		return
		
	_discovered_resources[resource_id] = true
	print_debug("%s: discovered resource=%s" % [name, resource.name])
	resource_discovered.emit(resource)
