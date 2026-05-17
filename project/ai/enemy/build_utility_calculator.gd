class_name BuildUtilityCalculator extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var team_units: TeamUnits = %TeamUnits
@onready var enemy_teams: EnemyTeams = %EnemyTeams

@export
var behaviors:Dictionary[ConstructionResource.Type, UtilityAIBehavior]

var _available_behaviors:Dictionary[ConstructionResource.Type, UtilityAIBehavior]

var match_team:MatchTeam

var _viable_options: Array[UtilityAIOption]
var _manufacturing_by_type: Dictionary[ConstructionResource.Type, Array]
var _enemy_unit_distributions: Dictionary[ConstructionResource.Type, int]

func refresh() -> void:
	_refresh_available_behaviors()
	_refresh_enemy_data()
	
func _refresh_available_behaviors() -> void:
	_manufacturing_by_type.clear()
	_available_behaviors.clear()
	
	# Map construction resource types to their supported manufacturing centers
	for building in team_units.buildings:
		var manufacturing_component:ManufacturingComponent = ManufacturingComponent.get_component(building)
		if manufacturing_component:
			for resource in manufacturing_component.supported_types.types:
				var type:ConstructionResource.Type = resource.type
				# Only add if we have a behavior binding
				# Some levels for instance may not allow AI to build certain types of units/buildings
				if type in behaviors:
					var manufacturing_options: Array[ManufacturingComponent] = \
						_manufacturing_by_type.get_or_add(type, [] as Array[ManufacturingComponent])
						
					# First time adding - also add behavior binding
					if not manufacturing_options:
						_available_behaviors[type] = behaviors[type]
					manufacturing_options.push_back(manufacturing_component)
	
func _refresh_enemy_data() -> void:
	_enemy_unit_distributions.clear()
	
	var team_distributions: Dictionary[ConstructionResource.Type, int]
	for team:EnemyTeamUnits in enemy_teams:
		var assets := team.assets
		team_distributions.clear()
		for asset_id in assets:
			var asset_data:UnitData = assets[asset_id]
			if asset_data.valid:
				_count_unit_by_type(asset_data.asset as Unit, team_distributions)
			
		# Take the maximum of unit types across teams
		for type in team_distributions:
			_enemy_unit_distributions[type] = maxi(_enemy_unit_distributions.get(type, 0), team_distributions[type])

func _count_unit_by_type(unit:Unit, team_distributions:Dictionary[ConstructionResource.Type, int]) -> void:
	if not unit:
		return
	var type:ConstructionResource.Type = ConstructionResource.type_from_unit_class(unit.unit_class)
	if type:
		team_distributions[type] = team_distributions.get(type, 0) + 1	
		
func next_build() -> bool:
	if not match_team:
		return false
	
	_viable_options.clear()
	
	var team_distributions: Dictionary[ConstructionResource.Type, int]
	var team_assets := team_units.assets_dict
	var total_units:int = 0
	for asset_id in team_assets:
		var unit:Unit = team_assets[asset_id] as Unit if is_instance_valid(asset_id) else null
		if unit:
			total_units += 1
			_count_unit_by_type(unit, team_distributions)
	
	var team_resources: TeamResources = match_team.resources
	var personnel:PersonnelResource = team_resources.personnel
	var scrap:ScrapResource = team_resources.scrap
	var available_personnel:int = personnel.remaining
	var available_scrap:int = scrap.count
		
	for type in _available_behaviors:
		var manufacturing_options: Array[ManufacturingComponent] = _manufacturing_by_type.get(type, [] as Array[ManufacturingComponent])
		if not manufacturing_options:
			continue
		manufacturing_options.sort_custom(func(a:ManufacturingComponent, b:ManufacturingComponent) -> bool:
			return a.available_build_slots > b.available_build_slots
			)
		# picking candidate with most free slots and all other criteria would be the same so just check if best candidate can build
		var candidate:ManufacturingComponent = manufacturing_options.front()
		# Don't filter out those that can build due to resource constraints as want AI to wait and accumulate resources if that's
		# the right thing to build
		if candidate.has_free_slot:
			var utility_context:BuildUnitUtilityContext = BuildUnitUtilityContext.new()
			utility_context.id = candidate.get_instance_id()
			utility_context.army_fraction = float(team_distributions.get(type, 0)) / total_units if total_units > 0 else 0.0
			utility_context.construction = candidate.get_build_metadata(type)
			utility_context.available_personnel = available_personnel
			utility_context.available_scrap = available_scrap
			utility_context.enemy_delta = _enemy_unit_distributions.get(type, 0) - team_distributions.get(type, 0)
			
			var behavior:UtilityAIBehavior = behaviors[type]
			var action:Callable = func() -> bool:
				if candidate.can_build(type):
					@warning_ignore("missing_await")
					candidate.build(type)
					return true
				return false
				
			_viable_options.push_back(UtilityAIOption.new(behavior, utility_context, action))
	
	if not _viable_options:
		return false
			
	# TODO: Buildings will be queued using a simple rule-based strategy
	# First need command center, next need barracks, then factory
	# Can then proceed to build additional barracks and factory if units are queing up too much
	# When decide to expand then will start this process over so the checks need to be localized
	# based on a base or "resource cluster" radius
	
	var best_option := UtilityAI.choose_highest(_viable_options)
	
	SignalBus.on_utility_calculation.emit(name, blackboard.team, _viable_options, best_option)
	
	var success:bool = best_option.action.call()
	if not success:
		SignalBus.on_utility_calculation_complete.emit(name, blackboard.team)
	
	return success
