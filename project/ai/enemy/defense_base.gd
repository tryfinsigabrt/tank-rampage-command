@tool
extends ActionLeaf

const DEFEND_AREA_PRIORITY_V_GAP = preload("uid://cqvrrxfqw8vws")

@export
var defense_radius:float = 25.0

@export
var defense_radius_buffer:float = 5.0

@export
var angle_increment_deg:float = 30.0

@export
var defense_time:float = 30.0

class BuildingData:
	var bounds:BoundingSphere
	var defense_bounds:BoundingSphere
	var angle:float
	var target_radius:float
	var forward:Vector3
	
	func _init(building:Building, in_defense_radius:float) -> void:
		bounds = Bounds.new(building.get_global_bounds()).circumscribed_sphere
		defense_bounds = BoundingSphere.new(bounds.center, bounds.radius + in_defense_radius)
		forward = building.global_forward
		
var _building_data:Dictionary[int, BuildingData]

func tick(_actor: Node, in_blackboard: Blackboard) -> int:
	var blackboard: EnemyTeamBlackboard = in_blackboard
	
	var base_defenders:Dictionary[int,EnemyTeamBlackboard.BaseDefenseContext] = blackboard.base_defend_units
	if not base_defenders:
		return SUCCESS
	
	for id:int in _building_data.keys():
		if not is_instance_id_valid(id):
			_building_data.erase(id)
		else:
			var data:BuildingData = _building_data[id]
			data.angle = 0.0
	
	var angle_increment_rad:float = deg_to_rad(angle_increment_deg)
		
	for defender_id in base_defenders:
		var defender:Unit = instance_from_id(defender_id) as Unit
		if not defender or not defender.weapon:
			continue
		
		var building_context := 	base_defenders[defender_id]
		var building_id:int = building_context.asset_id
		var defensive_gap:float = building_context.ideal_defense - building_context.current_defense
		var priority:int = roundi(DEFEND_AREA_PRIORITY_V_GAP.sample_baked(defensive_gap))
		var building_data:BuildingData
		if building_id in _building_data:
			building_data = _building_data[building_id]
		else:
			var building:Building = instance_from_id(building_id)
			if not building:
				continue
			building_data = BuildingData.new(building, defense_radius)
			_building_data[building_id] = building_data
		
		var unit_directives := AiUnitDirectives.get_component(defender)
		var defense_bounds:BoundingSphere = building_data.defense_bounds
		
		if OS.is_debug_build():
			print("%s: DEFENSE PRIORITY(%s): gap = %.1f priority = %d" % [name, instance_from_id(building_id).name, defensive_gap, priority])

		var state := unit_directives.set_defend_area(defense_bounds, defense_time, func() -> Vector3:
			var next_heading:Vector3 = building_data.forward.rotated(Vector3.UP, building_data.angle)
			var next_pos:Vector3 = defense_bounds.center + next_heading * maxf(defense_bounds.radius - defense_radius_buffer, defense_radius_buffer)		
			building_data.angle += angle_increment_rad
			
			return next_pos
		, priority)
		
		state.finished.connect((func() -> void:
			blackboard.base_defend_units.erase(defender_id)
		).unbind(1))
		
	return SUCCESS
