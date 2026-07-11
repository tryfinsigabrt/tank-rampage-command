class_name BuildUtilityCalculator extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var team_units: TeamUnits = %TeamUnits
@onready var enemy_teams: EnemyTeams = %EnemyTeams

@onready var base_location_prioritizer: BaseLocationPrioritizer = $BaseLocationPrioritizer
@onready var building_location_finder: BuildingLocationFinder = $BuildingLocationFinder
@onready var defense_structure_prioritizer: DefensiveStructurePrioritizer = $DefenseStructurePrioritizer

@onready var enemy_building_create_action: EnemyBuildingCreateAction = %EnemyBuildingCreateAction
@onready var failed_building_cooldown_timer: Timer = $FailedBuildingCooldownTimer

@export
var behaviors:Dictionary[ConstructionResource.Type, UtilityAIBehavior]

## Temporary flag while the feature is still in development
@export
var allow_buildings:bool = false

@export
var allow_structures:bool = false

## Initial delay to build any buildings because the unit manufacturing doesn't come in right away
@export
var buildings_delay:float = 3.0

@export
var failed_building_cooldown_time:float = 10.0

var _available_behaviors:Dictionary[ConstructionResource.Type, UtilityAIBehavior]

var match_team:MatchTeam

var _viable_options: Array[UtilityAIOption]
var _manufacturing_by_type: Dictionary[ConstructionResource.Type, Array]
var _enemy_unit_distributions: Dictionary[ConstructionResource.Type, int]
var _construction_resources_by_type: Dictionary[ConstructionResource.Type, ConstructionResource]

var _building_stats_by_type:Dictionary[ConstructionResource.Type, BuildingStats]
var _command_center_data:CommandCenterData
var _can_build_buildings:bool
var _can_build_structures:bool

class AggregateDefenseNeeds:
	var score:float
	var strength:float
	var available_infantry_units:int
	
var _aggregate_defense_needs:AggregateDefenseNeeds = AggregateDefenseNeeds.new()

func _ready() -> void:
	failed_building_cooldown_timer.wait_time = failed_building_cooldown_time
	
func refresh() -> void:
	_refresh_available_behaviors()
	_refresh_enemy_data()
	
	# First obtain available behaviors where the mapping is relevant
	_refresh_construction_resource_mappings()
	
func _refresh_construction_resource_mappings() -> void:
	if not match_team:
		return
		
	_construction_resources_by_type.clear()
	
	var team_resource_component:TeamResourceComponent = match_team.team_resources
	
	for type in _available_behaviors:
		var construction_resource:ConstructionResource = team_resource_component.get_construction_resource(type)
		if construction_resource:
			_construction_resources_by_type[type] = construction_resource

func _refresh_available_behaviors() -> void:
	_manufacturing_by_type.clear()
	_available_behaviors.clear()
	
	_can_build_buildings = false
	_can_build_structures = false
	
	# Map construction resource types to their supported manufacturing centers
	for building in team_units.buildings:
		var manufacturing_component:ManufacturingComponent = ManufacturingComponent.get_component(building)
		if manufacturing_component:
			for resource in manufacturing_component.supported_types.types:
				var type:ConstructionResource.Type = resource.type
				var classification:ConstructionResource.Classification = resource.classification
				
				# Only add if we have a behavior binding
				# Some levels for instance may not allow AI to build certain types of units/buildings
				if type in behaviors and (classification != ConstructionResource.Classification.Structure or allow_structures):
					var manufacturing_options: Array[ManufacturingComponent] = \
						_manufacturing_by_type.get_or_add(type, [] as Array[ManufacturingComponent])
						
					# First time adding - also add behavior binding
					if not manufacturing_options:
						_available_behaviors[type] = behaviors[type]
						if classification == ConstructionResource.Classification.Structure:
							_can_build_structures = true
							
					manufacturing_options.push_back(manufacturing_component)
	if allow_buildings and GameManager.game_timer.time_seconds > buildings_delay:
		for type in behaviors:
			var type_classification:ConstructionResource.Classification = ConstructionResource.classify_type(type)
			if type_classification == ConstructionResource.Classification.Building:
				_available_behaviors[type] = behaviors[type]
				_can_build_buildings = true
			
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
	var team_structure_queue:Dictionary[ConstructionResource.Type, int]
	var unit_class_distributions:Dictionary[Unit.UnitClass, int]
	
	var team_assets := team_units.assets_dict
	var total_units:int = 0
	var queued_units:int = 0
	
	for asset_id in team_assets:
		if not is_instance_id_valid(asset_id):
			continue
		var asset:Node3D = team_assets[asset_id]
		if asset is Unit:
			total_units += 1
			_count_unit_by_type(asset, team_distributions)
			unit_class_distributions[asset.unit_class] = unit_class_distributions.get(asset.unit_class, 0) + 1
		elif asset is Building:
			# Consider the queue
			var manufacturing_comp:ManufacturingComponent = ManufacturingComponent.get_component(asset, false)
			if manufacturing_comp:
				for resource in manufacturing_comp.currently_building:
					var type := resource.type
					team_distributions[type] = team_distributions.get(type, 0) + 1

					var classification := resource.classification
					if classification == ConstructionResource.Classification.Unit:
						queued_units += 1
					elif classification == ConstructionResource.Classification.Structure:
						team_structure_queue[type] = team_structure_queue.get(type, 0) + 1
	
	var team_resources: TeamResources = match_team.resources
	var personnel:PersonnelResource = team_resources.personnel
	var scrap:ScrapResource = team_resources.scrap
	var available_personnel:int = personnel.remaining
	var available_scrap:int = scrap.count
		
	# Refresh on every build action since the stats are dependent on last build not just next cycle
	if _can_build_buildings:
		_refresh_non_command_center_building_stats()
		_refresh_command_center_building_stats()
	
	if _can_build_structures:
		_refresh_structure_build_data(team_structure_queue)
	
	for type in _available_behaviors:
		var behavior:UtilityAIBehavior = behaviors[type]
		var utility_context:Variant = null
		var action:Callable
		
		var type_classification:ConstructionResource.Classification = ConstructionResource.classify_type(type)
		if type_classification == ConstructionResource.Classification.Unit:
			# picking candidate with most free slots and all other criteria would be the same so just check if best candidate can build
			var candidate:ManufacturingComponent = _get_best_manufacturing_component(type)
			if not candidate:
				continue
			# Don't filter out those that can build due to resource constraints as want AI to wait and accumulate resources if that's
			# the right thing to build
			if candidate.has_free_slot:
				utility_context = BuildUnitUtilityContext.new()
				utility_context.id = candidate.get_instance_id()
				var live_and_queued_total_units:int = total_units + queued_units
				utility_context.army_fraction = float(team_distributions.get(type, 0)) / live_and_queued_total_units if live_and_queued_total_units > 0 else 0.0
				utility_context.construction = candidate.get_build_metadata(type)
				utility_context.available_personnel = available_personnel
				utility_context.available_scrap = available_scrap
				
				var enemy_count:int = _enemy_unit_distributions.get(type, 0)
				var team_count:int = team_distributions.get(type, 0)
				#print("ARMY FRACTION(%s): %d / %d -> %.2f" % [EnumUtils.enum_to_string(ConstructionResource.Type, type), team_distributions.get(type, 0), live_and_queued_total_units,  utility_context.army_fraction])
				
				utility_context.enemy_delta = enemy_count / float(team_count) if team_count > 0 else 1.0 if enemy_count > 0 else 0.5
				
				action = func() -> bool:
					if candidate.can_build(type):
						@warning_ignore("missing_await")
						candidate.build(type)
						return true
					return false
		elif type_classification == ConstructionResource.Classification.Building:
			if type not in _construction_resources_by_type:
				continue
			# Only allow a single outstanding placement task at one time
			# Two buildings able to build on top of each other if done on the same frame as physics hasn't processed yet
			if enemy_building_create_action.active_placements or not failed_building_cooldown_timer.is_stopped():
				continue
				
			var is_command_center:bool = type == ConstructionResource.Type.CommandCenter
			var viable_locations:Array[BoundingCircle]
			
			if is_command_center:
				var best_scrap_field_data := _command_center_data.best_open_field
				if not best_scrap_field_data:
					continue
				# ScrapField guaranteed to exist if there is a candidate match	
				var location:BoundingCircle = building_location_finder.get_command_center_building_bounds(instance_from_id(best_scrap_field_data.id))
				if location:
					viable_locations.push_back(location)
			else:
				viable_locations = building_location_finder.get_general_building_bounds(type)
				
			if not viable_locations:
				continue
			
			var construction := _construction_resources_by_type[type]			
			
			utility_context = BuildBuildingUtilityContext.new()
			utility_context.id = construction.get_instance_id()
			utility_context.construction = construction
			utility_context.available_scrap = available_scrap
			utility_context.curr_unit_count = total_units
			utility_context.target_location_bounds = viable_locations
			
			# Command center-specific context
			if is_command_center:
				_add_command_center_building_context(utility_context)
			else:
				_add_non_command_center_building_context(type, utility_context)
				
			action = func() -> bool:
				if enemy_building_create_action.can_create(utility_context):
					@warning_ignore("missing_await")
					enemy_building_create_action.create(utility_context)
					return true
				return false
		elif type_classification == ConstructionResource.Classification.Structure:
			var candidate:ManufacturingComponent = _get_best_manufacturing_component(type)
			if not candidate:
				continue
			if candidate.has_free_slot:
				utility_context = BuildStructureUtilityContext.new()
				utility_context.id = candidate.get_instance_id()
				utility_context.construction = candidate.get_build_metadata(type)
				utility_context.available_personnel = available_personnel
				utility_context.available_scrap = available_scrap
				utility_context.available_infantry_units = unit_class_distributions.get(Unit.UnitClass.Soldier, 0)
				utility_context.need_score = _aggregate_defense_needs.score
				utility_context.required_strength = _aggregate_defense_needs.strength
				
				action = func() -> bool:
					if candidate.can_build(type):
						@warning_ignore("missing_await")
						candidate.build(type)
						return true
					return false
						
		if utility_context:
			_viable_options.push_back(UtilityAIOption.new(behavior, utility_context, action))
	# end - For every available behavior
	
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
	
#region Manufacturing

func _get_best_manufacturing_component(type: ConstructionResource.Type) -> ManufacturingComponent:
	var manufacturing_options: Array[ManufacturingComponent] = _manufacturing_by_type.get(type, [] as Array[ManufacturingComponent])
	if not manufacturing_options:
		return null
	manufacturing_options.sort_custom(func(a:ManufacturingComponent, b:ManufacturingComponent) -> bool:
		return a.available_build_slots > b.available_build_slots
		)
	return manufacturing_options.front()

#endregion

#region Building Manufacturing
const _BUILDING_STATS_RESET_TIME:float = 120.0

class BuildingStats:
	var total_in_progress:int
	var total_queue_size:int
	var total_buildings:int
	var last_reset_time:float
	
	func new_record() -> void:
		total_buildings = 0
		
		var time:float = GameManager.game_timer.time_seconds
		if time - last_reset_time >= _BUILDING_STATS_RESET_TIME:
			last_reset_time = time
			total_in_progress = 0
			total_queue_size = 0
		
	func get_queue_depth_fraction() -> float:
		# Set avg queue depth to 1.0 if no buildings to push towards building that building
		return float(total_in_progress) / total_queue_size if total_queue_size > 0 else 1.0
	
class CommandCenterData:
	var most_depleted_field_fraction:float
	var time_to_exhaustion:float
	var best_open_field:EnemyTeamBlackboard.ScrapFieldData
	
func _get_building_stats_record(type: ConstructionResource.Type) -> BuildingStats:
	var stats:BuildingStats = _building_stats_by_type.get(type)
	if not stats:
		stats = BuildingStats.new()
		_building_stats_by_type[type] = stats
	return stats
		
func _refresh_non_command_center_building_stats() -> void:
	for type in _building_stats_by_type:
		_building_stats_by_type[type].new_record()
		
	for building in team_units.buildings:
		var building_type := ConstructionResource.type_from_building(building)
		var manufacturing_component:ManufacturingComponent = ManufacturingComponent.get_component(building)
		if manufacturing_component:
			var stats:BuildingStats = _get_building_stats_record(building_type)
			stats.total_buildings += 1
			stats.total_queue_size += manufacturing_component.max_queue
			stats.total_in_progress += manufacturing_component.queue_depth
	
	# for total buildings also consider those that are in progress of being built or placed
	for placement in enemy_building_create_action.active_placements:
		_get_building_stats_record(placement.context.type).total_buildings += 1
	
func _refresh_command_center_building_stats() -> void:
	var scrap_fields_data:Array[EnemyTeamBlackboard.ScrapFieldData] = blackboard.active_scrap_fields
	var team:int = match_team.team

	var most_depleted_field_fraction:float = 0.0
	var time_to_exhaustion:float = 0.0
	
	for scrap_field_data in scrap_fields_data:
		scrap_field_data.refresh_visible_data()
		if team not in scrap_field_data.teams:
			continue
		var field:ScrapField = instance_from_id(scrap_field_data.id)
		if not field:
			continue
		most_depleted_field_fraction = maxf(most_depleted_field_fraction, 1.0 - field.remaining_fraction)
		time_to_exhaustion = maxf(time_to_exhaustion, field.get_estimated_time_to_exhaustion())
		
	if not _command_center_data:
		_command_center_data = CommandCenterData.new()
			
	_command_center_data.most_depleted_field_fraction = most_depleted_field_fraction
	_command_center_data.time_to_exhaustion = time_to_exhaustion
	_command_center_data.best_open_field = base_location_prioritizer.get_best_open_scrap_field()
	
func _add_non_command_center_building_context(type: ConstructionResource.Type, context: BuildBuildingUtilityContext) -> void:
	var stats:BuildingStats = _get_building_stats_record(type)		
	context.avg_queue_depth_fraction = stats.get_queue_depth_fraction()
	context.curr_building_count = stats.total_buildings

func _add_command_center_building_context(context: BuildBuildingUtilityContext) -> void:
	context.most_depleted_field_fraction = _command_center_data.most_depleted_field_fraction
	context.time_to_exhaustion = _command_center_data.time_to_exhaustion
	context.build_site_score = _command_center_data.best_open_field.score

func _on_enemy_building_create_action_on_building_complete(context: BuildBuildingUtilityContext, building: Building) -> void:
	if building or failed_building_cooldown_time <= 0:
		return
	
	print_debug("%s: Failed to build %s - waiting %.1fs before attempting again" % [name, context.construction, failed_building_cooldown_time])
	
	failed_building_cooldown_timer.start()

#endregion

#region Structure Manufacturing

func _refresh_structure_build_data(team_structure_queue:Dictionary[ConstructionResource.Type, int]) -> void:
	var defense_needs := defense_structure_prioritizer.get_prioritized_current_needs()
	
	var total_strength:float = 0.0
	var total_score:float = 0.0
	
	for need in defense_needs:
		total_score += need.score
		total_strength += need.required_strength
	
	# Subtract out those in progress of building
	for type in team_structure_queue:
		var resource:ConstructionResource = _construction_resources_by_type.get(type)
		if not resource:
			push_warning("%s: type=%s is in progress of building but no construction resource mapping found!" % [name, EnumUtils.enum_to_string(ConstructionResource.Type, type)])
			continue
		var attrs:TeamAssetAttributes = resource.attributes
		if attrs:
			total_strength -= attrs.strength
	
	_aggregate_defense_needs.score = total_score
	_aggregate_defense_needs.strength = total_strength
#endregion
