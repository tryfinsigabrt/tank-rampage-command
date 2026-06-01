class_name Avoidance

const LAYER_ALL:int = 1

const _unit_type_bits:Dictionary[Unit.UnitClass, int] = {
	Unit.UnitClass.Soldier: 1 << 1,
	Unit.UnitClass.Tank: 1 << 2,
	Unit.UnitClass.Artillery: 1 << 3, # Vehicles have the same offset
}
const _unit_type_team_layers:Dictionary[Unit.UnitClass, int] = {
	Unit.UnitClass.Soldier: 4,
	Unit.UnitClass.Tank: 5,
	Unit.UnitClass.Artillery: 5, # Vehicles have the same offset
}

const _TEAM_STRIDE:int = 2

const _unit_type_team_bits:Dictionary[int, int] = {
	1: 0,
	2: _TEAM_STRIDE,
}

static func get_enemy_teams(team:int) -> PackedInt32Array:
	# Currently only two teams
	var enemy_teams:PackedInt32Array
	if team == 1:
		enemy_teams.push_back(2)
	elif team == 2:
		enemy_teams.push_back(1)
	return enemy_teams

static func get_avoidance_team_layer_mask(base_mask:int, unit_classes:Array[Unit.UnitClass], teams:PackedInt32Array) -> int:
	if not teams:
		for unit_class in unit_classes:
			base_mask |= _unit_type_bits.get(unit_class, 0)
		return base_mask
		
	for team in teams:
		var team_offset:int = _unit_type_team_bits.get(team, -1)
		if team_offset < 0:
			continue
			
		for unit_class in unit_classes:
			var layer:int = _unit_type_team_layers.get(unit_class, -1)
			if layer >= 0:
				base_mask |= (1 << (layer + team_offset))
	return base_mask
	
static func apply_avoidance_mask_to(unit:Unit) -> void:
	if not is_instance_valid(unit):
		return
	
	var nav:GameUnitNavigation = GameUnitNavigation.get_component(unit)
	if not nav:
		return
	
	var team_component:TeamComponent = TeamComponent.get_component(unit)
	
	var mask:int = nav.navigation_agent_3d.avoidance_mask
	var unit_class:Unit.UnitClass = unit.unit_class
	mask |= _unit_type_bits.get(unit_class, 0)
	if team_component:
		var team_offset:int = _unit_type_team_bits.get(team_component.team, -1)
		if team_offset >= 0:
			var unit_type_team_layer:int = _unit_type_team_layers.get(unit_class, -1)
			if unit_type_team_layer >= 0:
				mask |= (1 << (unit_type_team_layer + team_offset))
			
	nav.navigation_agent_3d.avoidance_mask = mask
