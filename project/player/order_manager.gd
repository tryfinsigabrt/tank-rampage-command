class_name OrderManager extends Node

@export
var selection_manager:SelectionManager

@export
var position_distribution:PositionDistributor

@export
var target_asset_selection_effect:AssetSelectionEffect

@export
var follow_unit_selection_effect:AssetSelectionEffect

# TODO: Could have a unit effect for loading units 
@onready
var load_unit_effect:AssetSelectionEffect = follow_unit_selection_effect

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

	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Attack)
	
	_reset_effects()
	target_asset_selection_effect.toggle_selection(to_attack, true)

func follow(leader:Unit) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	
	# unit must be on same team and must not already be in selected group
	if not is_instance_valid(leader) or not leader.is_on_team(selection_manager.team) or leader in units:
		print_debug("%s: Skip as leader=%s must be on same team and not already in selection" % [name, StringUtils.safe_name(leader)])
		return
	
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.follow(leader)
	
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Follow)
	
	_reset_effects()
	follow_unit_selection_effect.toggle_selection(leader, true)

func load_into(asset: Node3D) -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	
	# asset must be on same team and have a unit container component
	if not is_instance_valid(asset):
		push_error("%s: asset is not valid!" % name)
		return
		
	var team_component := TeamComponent.get_component(asset)
	if not team_component:
		# Already logged with assert
		return
	
	var unit_container := UnitContainerComponent.get_component(asset, false)
	if not team_component.is_on_team(selection_manager.team) or not unit_container:
		print_debug("%s: Skip as asset=%s must be on same team and have a UnitContainerComponent" % [name, StringUtils.safe_name(asset)])
		return
	
	# Load units that we can and rest do a regular move
	# If the bunker is full then the other units will end up doing a move too
	# This allows us to queue up a bunker and maybe unload the other units that are already in it in the meantime
	var asset_position:Vector3 = asset.global_position
	
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		if unit_container.supports_unit(unit):
			unit_actions.load_into(asset)
		else:
			unit_actions.move(asset_position)
			
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Load)
	_reset_effects()
	load_unit_effect.toggle_selection(asset, true)
	
func stop() -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.stop()
		
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Stop)
	
	_reset_effects()
	
func hold() -> void:
	var units := selection_manager.get_selected_units_on_team()
	if not units:
		return
	
	for unit in units:
		var unit_actions := unit.get_or_add_actions()
		unit_actions.hold()
		
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Hold)
	
	_reset_effects()	

func _reset_effects() -> void:
	move_to_effect.hide()
	attack_move_effect.hide()
	attack_position_effect.hide()
	
	target_asset_selection_effect.disable_all()
	follow_unit_selection_effect.disable_all()	
	
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
	
	SignalBus.on_order_manager_command_issued.emit(UnitBlackboard.Action.Attack)

	_reset_effects()
	attack_position_effect.display_at(position)
	
	return true
