class_name EnemyTeamDirector extends Node3D

@onready var team_units: TeamUnits = %TeamUnits
@onready var enemy_teams: EnemyTeams = %EnemyTeams
@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var behavior_tree: BeehaveTree = %BeehaveTree

@export
var team:int

func _ready() -> void:
	_discover_units_and_teams()
	_init_blackboard()
	
func _discover_units_and_teams() -> void:
	team_units.team = team

	var nodes:Array[Node] = get_tree().get_nodes_in_group(Groups.Unit)
	var enemy_team_ids:PackedInt32Array
	
	for node in nodes:
		var unit:Unit = node as Unit
		if not unit:
			push_warning("%s: node=%s in group 'Unit' but is not a Unit derived node" % [name, node.name])
			continue
		if unit.is_on_team(team):
			team_units.add_unit(unit)
		# We may not be able to see the unit yet but at least create the team
		elif not unit.team in enemy_team_ids:
			enemy_teams.add_team(unit.team)
			enemy_team_ids.push_back(unit.team)
			
	team_units.initialized.emit()
		
func _init_blackboard() -> void:
	blackboard.team_info = team_units
	blackboard.enemy_teams_info = enemy_teams
	blackboard.team = team
	blackboard.focus_position = team_units.get_average_position()
