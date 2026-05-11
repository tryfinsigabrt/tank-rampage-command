class_name AttackedTrackerComponent extends Node

const ComponentName:StringName = &"AttackedTrackerComponent"

var _team_asset_root:Node

var _health_comp:HealthStat
var _team_component:TeamComponent

func _ready() -> void:
	if not _team_asset_root:
		push_error("%s: AttackerTrackerComponent not added to a team asset hierarchy: " % name)
		queue_free()
		return
	_team_component = Components.get_component(Components.Team, _team_asset_root)
	if not _team_component:
		push_error("%s: AttackerTrackerComponent asset %s has no team_component!" % [name, _team_asset_root.name])
		queue_free()
		return
	_health_comp = Components.get_component(Components.Health, _team_asset_root)
	if not _health_comp:
		push_error("%s:  AttackerTrackerComponent asset %s has no health stat!" % [name, _team_asset_root.name])
		queue_free()
		return
	_health_comp.took_damage.connect(_on_took_damaged)
	
func _on_took_damaged(_damage_params:DamageParameters) -> void:
	# TODO:
	pass
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> AttackedTrackerComponent:
	return Components.get_component(ComponentName, node, required) as AttackedTrackerComponent
		
func _enter_tree() -> void:
	_team_asset_root = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if _team_asset_root:
		Components.add_component(ComponentName, self, _team_asset_root)

func _exit_tree() -> void:
	if _team_asset_root:
		Components.remove_component(ComponentName, self, _team_asset_root)
#endregion
