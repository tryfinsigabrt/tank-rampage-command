class_name EnemyTeamDirector extends Node3D

@onready var team_units: TeamUnits = %TeamUnits
@onready var enemy_teams: EnemyTeams = %EnemyTeams
@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var behavior_tree: BeehaveTree = %BeehaveTree

@export
var team:int

func _ready() -> void:
	await _discover_units_and_teams()
	_init_blackboard()
	
	SignalBus.on_team_asset_added.connect(_on_asset_added)

func _on_asset_added(asset:Node3D) -> void:
	# Already accounted for on initial discovery
	if asset.has_meta(MatchTeam.IS_PREDEPLOYED_KEY):
		return
	var team_component:TeamComponent = TeamComponent.get_component(asset)
	if not team_component or not team_component.is_on_team(team):
		return
	
	if asset.is_in_group(Groups.Unit):
		team_units.add_unit(asset)
	elif asset.is_in_group(Groups.Building):
		team_units.add_building(asset)
	elif asset.is_in_group(Groups.Structure):
		team_units.add_structure(asset)
	
func _discover_units_and_teams() -> void:
	team_units.team = team

	var enemy_team_ids:PackedInt32Array
	
	_add_assets(Groups.Unit, Unit, enemy_team_ids, func(unit:Unit) -> void:
		team_units.add_unit(unit)
	)
	
	_add_assets(Groups.Building, Building, enemy_team_ids, func(building:Building) -> void:
		team_units.add_building(building)
	)
	
	_add_assets(Groups.Structure, Node3D, enemy_team_ids, func(structure:Node3D) -> void:
		team_units.add_structure(structure)
	)
			
	await team_units.initialize()

func _add_assets(group: StringName, type: Variant, enemy_team_ids:PackedInt32Array, team_units_adder:Callable) -> void:
	var nodes:Array[Node] = get_tree().get_nodes_in_group(group)
	
	for node in nodes:
		var asset:Node3D = node as Node3D
		if not asset or not is_instance_of(asset, type):
			push_warning("%s: node=%s in group '%s' but is not a %s derived node" % [name, node.name, group, type])
			continue
	
		var team_component:TeamComponent = Components.get_component(Components.Team, asset)
		if not team_component:
			push_warning("%s: node=%s does not have a TeamComponent" % [name, asset.name])
			continue
			
		if team_component.is_on_team(team):
			asset.set_meta(MatchTeam.IS_PREDEPLOYED_KEY, true)
			team_units_adder.call(asset)
		# We may not be able to see the asset yet but at least create the team
		elif not team_component.team in enemy_team_ids:
			enemy_teams.add_team(team_component.team)
			enemy_team_ids.push_back(team_component.team)
			
func _init_blackboard() -> void:
	blackboard.team_info = team_units
	blackboard.enemy_teams_info = enemy_teams
	blackboard.team = team
	blackboard.match_team = GameManager.find_match_team_by_id(team)
	blackboard.focus_position = team_units.get_average_position()
