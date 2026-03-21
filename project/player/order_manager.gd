class_name OrderManager extends Node

@export
var selection_manager:SelectionManager

@export
var position_distribution:PositionDistributor

func move(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	var positions_dict := position_distribution.calculate(units, position)
	
	for unit in units:
		var action := unit.get_or_add_actions()
		var pos := positions_dict[unit.get_instance_id()]
		action.move(pos)
		
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(position, 5.0, Color.YELLOW, 3.0)
		
func move_and_attack(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	var positions_dict := position_distribution.calculate(units, position)

	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		var pos := positions_dict[unit.get_instance_id()]

		unit_actions.move_and_attack(pos)
		
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(position, 5.0, Color.ORANGE, 3.0)

func attack(to_attack:Node3D) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	# Don't attack a unit in the group
	if to_attack in units:
		print_debug("%s: Skipping as to_attack=%s is in the selected group" % [name, to_attack.name])
		return
		
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.attack(to_attack)

func attack_position(position:Vector3) -> bool:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return false
		
	# Only attack a position if all units in the group support it
	for unit in units:
		var weapon: Weapon = unit.weapon
		if not weapon or not weapon.allow_position_attack:
			return false
			
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.attack_position(position)
	
	return true
