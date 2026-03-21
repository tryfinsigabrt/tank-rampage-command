class_name TeamComponent extends Node

signal update_render(in_render:bool)

@export
var team_asset:Node3D

@export
var team:int:
	set(value):
		if value == team:
			return
		team = value
		if is_node_ready():
			refresh_team_layers()
			
			
@export_range(1.0, 1e9, 0.1, "or_greater")
var vision:float = 50.0

var render:bool = true:
	set(value):
		if value == render:
			return
		render = value
		update_render.emit(value)
		
var team_visibility_mask:int

func _ready() -> void:
	if not team_asset:
		team_asset = Groups.get_scene_root(self)
		if team_asset:
			push_warning("%s: No team_asset set, defaulting to scene root: %s" % [name, StringUtils.safe_name(team_asset)])
		else:
			push_error("%s: No team_asset set and no appropriate default could be found" % name)
			
	refresh_team_layers.call_deferred()
	
func refresh_team_layers() -> void:
	if team_asset:
		Collisions.apply_team_collision_layer(team_asset, team)
		Visibility.apply_team_collision_layer(team_asset, team)
		
	if GameManager.fog_of_war:
		set_visible_to(team, true)
	else:
		# Everything visible
		team_visibility_mask = 0xffffffff
	
func on_same_team(team_component:TeamComponent) -> bool:
	return team_component and team_component.team == team
	
func is_on_team(in_team:int) -> bool:
	return team == in_team

static func to_team_mask(in_team:int) -> int:
	return in_team << (in_team - 1)
	
func is_visible_to(in_team:int) -> bool:
	return team_visibility_mask & to_team_mask(in_team)

func set_visible_to(in_team:int, in_visible:bool):
	var team_mask:int = to_team_mask(in_team)
	if in_visible:
		team_visibility_mask |= team_mask
	else:
		team_visibility_mask &= ~team_mask
	
# TODO: Right now don't have concept of allied teams but this leaves that open for future
func is_ally(team_component:TeamComponent) -> bool:
	return on_same_team(team_component)
	
func is_ally_team(in_team:int) -> bool:
	return is_on_team(in_team)
	
func is_enemy(team_component:TeamComponent) -> bool:
	return team_component and not is_ally(team_component)
	
func is_enemy_team(in_team:int) -> bool:
	return not is_ally_team(in_team)
