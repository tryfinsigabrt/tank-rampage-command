class_name MatchTeamStatTracker extends Node

var _match_team:MatchTeam

var units_killed:int
var units_built:int	
var units_lost:int
	
var buildings_constructed:int
var buildings_destroyed:int
var buildings_lost:int


func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	assert(_match_team)
	if not _match_team:
		push_error("%s: Not in tree with MatchTeam parent" % name)
		return
	
	# Don't add listeners until match starts to avoid tracking predeployed assets as "built"
	SignalBus.match_ready.connect(func(_match:Match) -> void:
		SignalBus.on_team_asset_added.connect(_on_team_asset_added)
		SignalBus.on_team_asset_destroyed.connect(_on_team_asset_destroyed)
	, ConnectFlags.CONNECT_ONE_SHOT)

func _on_team_asset_added(asset:Node3D) -> void:
	if not _match_team.active:
		return
		
	var team_component := TeamComponent.get_component(asset)
	if not team_component or not team_component.is_on_team(_match_team.team):
		return
	
	if asset is Unit:
		units_built += 1
	elif asset is Building:
		buildings_constructed += 1
		
func _on_team_asset_destroyed(asset:Node3D, damage_params:DamageParameters) -> void:
	if not _match_team.active:
		return
		
	var team_component := TeamComponent.get_component(asset)
	if team_component and team_component.is_on_team(_match_team.team):
		_asset_lost(asset)
	elif damage_params.source_owner:
		var damage_team_component := TeamComponent.get_component(damage_params.source_owner)
		if damage_team_component and damage_team_component.is_on_team(_match_team.team):
			_asset_killed(asset)

func _asset_lost(asset:Node3D) -> void:
	if asset is Unit:
		units_lost += 1
	elif asset is Building:
		buildings_lost += 1

func _asset_killed(asset:Node3D) -> void:
	if asset is Unit:
		units_killed += 1
	elif asset is Building:
		buildings_destroyed += 1
