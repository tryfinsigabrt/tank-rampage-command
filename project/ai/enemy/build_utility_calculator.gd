class_name BuildUtilityCalculator extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var team_units: TeamUnits = %TeamUnits
@onready var enemy_teams: EnemyTeams = %EnemyTeams

@export
var behaviors:Dictionary[ConstructionResource.Type, UtilityAIBehavior]

var match_team:MatchTeam

var _manufacturing: Array[ManufacturingComponent]
#var _viable_options: Array[UtilityAIOption]

func refresh() -> void:
	_manufacturing.clear()
	for building in team_units.buildings:
		var manufacturing_component:ManufacturingComponent = ManufacturingComponent.get_component(building)
		if manufacturing_component:
			_manufacturing.push_back(manufacturing_component)
			
func next_build() -> bool:
	if not match_team:
		return false
	
	# TODO: Buildings will be queued using a simple rule-based strategy
	# First need command center, next need barracks, then factory
	# Can then proceed to build additional barracks and factory if units are queing up too much
	# When decide to expand then will start this process over so the checks need to be localized
	# based on a base or "resource cluster" radius
	
	# TODO: Build the context for each behavior and filter viable_options to only those that can be built
	# by available manufacturing components and available resources
	# The action of the utility option will be the manufacturing build command bound as a callable
	#  ManufacturingComponent.build(type: ConstructionResource.Type)
	
	# Add debug hud for insight into the build utility - mirroring unit action by emitting a signal
	return false
