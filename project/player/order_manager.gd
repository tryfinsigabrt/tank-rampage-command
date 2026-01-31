class_name OrderManager extends Node

@export
var selection_manager:SelectionManager


func move(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	for unit in units:
		var action := unit.get_or_add_actions()
		action.move(position)
		
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(position, 5.0, Color.YELLOW, 3.0)
		
func move_and_attack(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.move_and_attack(position)
		
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(position, 5.0, Color.ORANGE, 3.0)

func attack(to_attack:Unit) -> void:
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
