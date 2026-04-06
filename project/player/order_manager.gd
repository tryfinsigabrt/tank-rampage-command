class_name OrderManager extends Node

@export
var selection_manager:SelectionManager

@export
var position_distribution:PositionDistributor

@export
var target_asset_selection_effect:AssetSelectionEffect

@export
var move_to_effect:GroundActionIndicator

@export
var attack_move_effect:GroundActionIndicator

@export
var attack_position_effect:GroundActionIndicator

func move(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	var positions_dict := position_distribution.calculate(units, position)
	
	for unit in units:
		var action := unit.get_or_add_actions()
		var pos := positions_dict[unit.get_instance_id()]
		action.move(pos)
		
	selection_manager.unit_order_dispatched()
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Move)
	
	_reset_effects()
	move_to_effect.display_at(position)
	#if OS.is_debug_build():
	#	DebugDraw3D.draw_sphere(position, 5.0, Color.YELLOW, 3.0)
		
func move_and_attack(position:Vector3) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
		
	var positions_dict := position_distribution.calculate(units, position)

	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		var pos := positions_dict[unit.get_instance_id()]

		unit_actions.move_and_attack(pos)
	
	selection_manager.unit_order_dispatched()
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.MoveAndAttack)
	
	_reset_effects()
	attack_move_effect.display_at(position)
	#if OS.is_debug_build():
		#DebugDraw3D.draw_sphere(position, 5.0, Color.ORANGE, 3.0)

func attack(to_attack:Node3D) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	# Don't attack a unit in the group
	# Only units can be in a selection group so check first that to_attack is a Unit
	if to_attack is Unit and to_attack in units:
		print_debug("%s: Skipping as to_attack=%s is in the selected group" % [name, to_attack.name])
		return
		
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.attack(to_attack)

	selection_manager.unit_order_dispatched()
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Attack)
	
	_reset_effects()
	target_asset_selection_effect.toggle_selection(to_attack, true)

func _reset_effects() -> void:
	move_to_effect.hide()
	attack_move_effect.hide()
	attack_position_effect.hide()
	target_asset_selection_effect.disable_all()
	
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
	
	selection_manager.unit_order_dispatched()
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Attack)

	_reset_effects()
	attack_position_effect.display_at(position)
	
	return true
