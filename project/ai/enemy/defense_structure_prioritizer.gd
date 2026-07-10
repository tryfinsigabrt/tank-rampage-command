class_name DefensiveStructurePrioritizer extends Node

var _dirty:bool

var _defense_needs_by_type:Dictionary[EnemyTeamBlackboard.DefenseNeedType, Array]
var _all_needs:Array[DefensiveStructureNeed]

class DefensiveStructureNeed:
	var type:EnemyTeamBlackboard.DefenseNeedType
	var defended_node:Node3D
	var score:float
	var build_bounds:BoundingCircle
	var required_strength:float
	
	
func get_prioritized_current_needs() -> Array[DefensiveStructureNeed]:
	if not _dirty:
		return _all_needs
		
	_all_needs.clear()
	
	for type in _defense_needs_by_type:
		var needs:Array[DefensiveStructureNeed] = _defense_needs_by_type[type]
		for need in needs:
			if is_instance_valid(need.defended_node):
				_all_needs.push_back(need)
	
	_all_needs.sort_custom(func(a:DefensiveStructureNeed, b:DefensiveStructureNeed) -> bool:
		return a.score > b.score)
		
	_dirty = false
	return _all_needs
		
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
	need.required_strength = maxf(needed_defense, 1.0)
	
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
