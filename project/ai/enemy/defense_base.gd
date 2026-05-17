@tool
extends ActionLeaf

@export
var defense_radius:float = 25.0

@export
var defense_radius_buffer:float = 5.0

@export
var angle_increment_deg:float = 30.0


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
	
	var base_defenders:Dictionary[int,int] = blackboard.base_defend_units
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
		if not defender:
			continue
		var building_id:int = base_defenders[defender_id]
		var building_data:BuildingData
		if building_id in _building_data:
			building_data = _building_data[building_id]
		else:
			var building:Building = instance_from_id(building_id)
			building_data = BuildingData.new(building, defense_radius)
			_building_data[building_id] = building_data
		
		# if defender move target or current hold position within the defense radius then no new order required
		var unit_actions:UnitActions = defender.get_or_add_actions()
		var current_pos:Vector3 = defender.global_position
		if unit_actions.has_target_position():
			var target_pos:Vector3 = unit_actions.get_target_position()
			if building_data.defense_bounds.contains(target_pos):
				continue
		elif building_data.defense_bounds.contains(current_pos):
			if not unit_actions.is_hold():
				unit_actions.hold()
			continue
		
		# Issue move and attack to the next position
		var defense_bounds:BoundingSphere = building_data.defense_bounds
		var next_heading:Vector3 = building_data.forward.rotated(Vector3.UP, building_data.angle)
		var next_pos:Vector3 = defense_bounds.center + next_heading * maxf(defense_bounds.radius - defense_radius_buffer, defense_radius_buffer)
		unit_actions.move_and_attack(next_pos)
		
		building_data.angle += angle_increment_rad
		
	return SUCCESS
