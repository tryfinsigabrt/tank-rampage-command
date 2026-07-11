class_name DefensiveStructurePrioritizer extends Node

@onready var enemy_building_create_action: EnemyBuildingCreateAction = %EnemyBuildingCreateAction

var _dirty:bool
var _inventory_component:InventoryComponent

var _defense_needs_by_type:Dictionary[EnemyTeamBlackboard.DefenseNeedType, Array]
var _all_needs:Array[DefensiveStructureNeed]

class InventoryData:
	var resource:ConstructionResource
	var strength:float
	var count:int
	
class DefensiveStructureNeed:
	var type:EnemyTeamBlackboard.DefenseNeedType
	var defended_node:Node3D
	var score:float
	var build_bounds:BoundingCircle
	var required_strength:float
	
	static func natural_order(a:DefensiveStructureNeed, b:DefensiveStructureNeed) -> bool:
		return a.score > b.score
	
	
func _ready() -> void:
	var match_team:MatchTeam = Groups.get_parent_with_type(self, MatchTeam)
	assert(match_team)
	await NodeUtils.ensure_ready(match_team)
	
	_inventory_component = match_team.inventory_component
	_inventory_component.inventory_changed.connect(_on_inventory_changed)
	
func get_prioritized_current_needs() -> Array[DefensiveStructureNeed]:
	# Make sure priority data up to date
	if _dirty:
		_tick()
	return _all_needs

func _tick() -> void:
	if not _dirty:
		return
		
	_all_needs.clear()
	
	for type in _defense_needs_by_type:
		var needs:Array[DefensiveStructureNeed] = _defense_needs_by_type[type]
		for need in needs:
			if is_instance_valid(need.defended_node):
				_all_needs.push_back(need)
	
	_all_needs.sort_custom(DefensiveStructureNeed.natural_order)
	
	# Build from available inventory based on need
	_build_from_inventory()
	
	_dirty = false
	
func _get_inventory_data() -> Dictionary[ConstructionResource.Type, InventoryData]:
	var data_map:Dictionary[ConstructionResource.Type, InventoryData]
	if not _inventory_component:
		return data_map
		
	for type in _inventory_component.get_available_types():
		var resource := _inventory_component.get_resource(type)
		if not resource:
			continue
		
		var data:InventoryData = InventoryData.new()
		data.resource = resource
		
		var attr := resource.attributes
		if attr:
			data.strength = attr.strength
			
		data.count = _inventory_component.get_count(type)
		
		data_map[type] = data
	
	return data_map
	
func _build_from_inventory() -> void:
	var inventory_data := _get_inventory_data()
	if not inventory_data:
		return
		
	var all_iterations_changed:bool = true
	var iteration_changed:bool = true

	while inventory_data and _all_needs:
		if not iteration_changed:
			all_iterations_changed = false
		else:
			iteration_changed = false
		
		for need in _all_needs:
			var selected_inventory:InventoryData = null
			# Prefer turrets on control point unless it is overkill
			if need.type == EnemyTeamBlackboard.DefenseNeedType.CONTROL_POINT:
				var candidate_inventory: InventoryData = inventory_data.get(ConstructionResource.Type.Turret)
				if candidate_inventory and candidate_inventory.strength <= need.required_strength:
					selected_inventory = candidate_inventory
			if not selected_inventory:
				# Pick weakest one that meets the need
				var best_diff:float = need.required_strength
				# By default only choose those that don't exceed the strength requirement unless all exceed the requirement
				if all_iterations_changed:
					for type in inventory_data:
						var inventory := inventory_data[type]
						# Find closest match that best meets the strength requirement
						var diff:float = need.required_strength - inventory.strength
						if diff < best_diff and diff >= 0:
							best_diff = diff
							selected_inventory = inventory
				else:
					var best_diff_abs:float = best_diff
					for type in inventory_data:
						var inventory := inventory_data[type]
						# Find closest match that best meets the strength requirement
						var diff:float = need.required_strength - inventory.strength
						var diff_abs:float = absf(diff)
						var compare:float = diff_abs - best_diff_abs
						
						var better:bool = false
						if is_zero_approx(compare):
							# Prefer exceeding strength than falling short if the magnitude is the same
							if diff < 0 and best_diff > 0:
								better = true
						else:
							better = compare < 0
							
						if better:
							best_diff = diff
							best_diff_abs = diff_abs
							selected_inventory = inventory
			if selected_inventory:
				_place_defensive_structure(selected_inventory, need)
				selected_inventory.count -= 1
				iteration_changed = true
				if selected_inventory.count == 0:
					inventory_data.erase(selected_inventory.resource.type)
					if not inventory_data:
						break
		# end for
		_prune_and_sort_needs()
	#end while				

func _prune_and_sort_needs() -> void:
	_all_needs.sort_custom(DefensiveStructureNeed.natural_order)
	# Remove strength needs that are now <= 0
	var remove_index:int = -1
	for i in _all_needs.size():
		if _all_needs[i].required_strength <= 0:
			remove_index = i
			break
	if remove_index != -1:
		for i in _all_needs.size() - remove_index:
			_all_needs.pop_back()
			
#region Signal Sinks

func _on_blackboard_defense_needs_are_updating(type: EnemyTeamBlackboard.DefenseNeedType, is_start: bool) -> void:
	if not is_start:
		return
		
	_dirty = true
	
	var needs:Array[DefensiveStructureNeed]
	if type in _defense_needs_by_type:
		needs = _defense_needs_by_type.get(type)
		needs.clear()
	else:
		_defense_needs_by_type[type] = needs
	
func _on_blackboard_defense_need_updated(type: EnemyTeamBlackboard.DefenseNeedType, data: Variant) -> void:
	match type:
		EnemyTeamBlackboard.DefenseNeedType.CONTROL_POINT:
			_on_control_point_defense_updated(type, data)
		EnemyTeamBlackboard.DefenseNeedType.BUILDING:
			_on_base_defense_updated(type, data)
		_:
			push_warning("%s: Unhandled defense need type %s" % [name, EnumUtils.enum_to_string(EnemyTeamBlackboard.DefenseNeedType, type)])
	
func _on_control_point_defense_updated(type: EnemyTeamBlackboard.DefenseNeedType, data: ControlPointPrioritizer.ControlPointContext) -> void:
	# Determine if a need should be created
	# If our strength is below a fixed value then we should defend it
	var strength_diff:float = data.our_strength - data.threat_strength
	if strength_diff > 0.0 and data.our_strength > 20:
		return
	
	var need:DefensiveStructureNeed = DefensiveStructureNeed.new()
	need.type = type
	need.defended_node = data.control_point_data.control_point
	need.required_strength = maxf(strength_diff, 1.0)
	need.score = need.required_strength * 2.0
	
	var bounds:BoundingCircle = data.bounds.clone()
	bounds.expand(bounds.radius * 0.5)
	need.build_bounds = bounds
	
	var needs:Array[DefensiveStructureNeed] = _defense_needs_by_type[type]
	needs.push_back(need)
	
func _on_base_defense_updated(type: EnemyTeamBlackboard.DefenseNeedType, data: BaseDefense.BaseDefenseContext) -> void:	
	var needed_defense:float = data.ideal_defense
	var current_defense:float = data.current_defense
	var defense_deficit:float = needed_defense - current_defense
	
	if defense_deficit > 0.0 and current_defense > 10.0:
		return
	
	var need:DefensiveStructureNeed = DefensiveStructureNeed.new()
	var asset:Node3D = instance_from_id(data.asset_id)
	
	need.type = type
	need.defended_node = asset
	need.required_strength = maxf(defense_deficit, 1.0)
	
	var score_multiplier:float
	var bounds_multipler:float
	if asset is CommandCenter:
		score_multiplier = 3.0
		bounds_multipler = 1.0
	else:
		score_multiplier = 1.0
		bounds_multipler = 2.0
		
	need.score = need.required_strength * score_multiplier
	
	var bounds:Bounds = data.bounds
	var build_bounds:BoundingCircle = BoundingCircle.from_bounds(bounds, true)
	build_bounds.expand(bounds.radius * bounds_multipler)
	need.build_bounds = build_bounds
	
	var needs:Array[DefensiveStructureNeed] = _defense_needs_by_type[type]
	needs.push_back(need)
	
#endregion

func _on_inventory_changed(resource:ConstructionResource, count:int) -> void:
	# Force re-evaluation
	if count > 0 and resource.classification == ConstructionResource.Classification.Structure:
		_dirty = true
		_tick()

func _place_defensive_structure(inventory_data:InventoryData, need:DefensiveStructureNeed) -> void:
	var context := DummyPlacementUtilityContext.create_from(inventory_data.resource, need)
	if not enemy_building_create_action.can_create(context):
		return
	
	# Only decrement the strength if we can actually build the resource, which should always pass 
	need.required_strength -= inventory_data.strength
	
	@warning_ignore("missing_await")
	enemy_building_create_action.create(context)
	
# TODO: This is a little awkward but BuildManufacturingActions requires a utility context and deploying structures is a two step process
# Build utility is in charge of figuring out what to build and this class is designed on how much we need defense and what to do with available defensive resources
class DummyPlacementUtilityContext extends AbstractBuildPlacementUtilityContext:
	static func create_from(resource:ConstructionResource, need:DefensiveStructureNeed) -> DummyPlacementUtilityContext:
		var context := DummyPlacementUtilityContext.new()
		context.id = need.defended_node.get_instance_id()
		context.target_location_bounds = [need.build_bounds]
		context.construction = resource
		
		return context
