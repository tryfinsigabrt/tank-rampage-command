extends VBoxContainer

@onready var header: Label = $Header
@onready var body: Label = $Body

var _lines:PackedStringArray

@export
var team:int = 2

const SCHEDULED:StringName = &"Scheduled"
const STARTED:StringName = &"Started"
const FINISHED:StringName = &"Finished"

class UnitState:
	var unit:Unit
	var time:float
	var command:StringName
	var state:StringName
	var command_id:int = -1
	var args:Dictionary[StringName,Variant]
	var move_target:Vector3 = Vector3.INF
	
var _unit_state_dict:Dictionary[int, UnitState]

func _enter_tree() -> void:
	SignalBus.on_unit_added.connect(_on_unit_added)
	SignalBus.on_unit_command_scheduled.connect(_on_command.bind(SCHEDULED))
	SignalBus.on_unit_command_started.connect(_on_command.bind(STARTED))
	SignalBus.on_unit_command_finished.connect(_on_command.bind(FINISHED))
	
	SignalBus.on_unit_move_issued.connect(_on_unit_move)
	SignalBus.on_unit_move_canceled.connect(_on_unit_move.unbind(1).bind(Vector3.INF))
	SignalBus.on_destination_reached.connect(_on_unit_move.unbind(1).bind(Vector3.INF))

func _exit_tree() -> void:
	SignalBus.on_unit_added.disconnect(_on_unit_added)
	SignalBus.on_unit_command_scheduled.disconnect(_on_command)
	SignalBus.on_unit_command_started.disconnect(_on_command)
	SignalBus.on_unit_command_finished.disconnect(_on_command)
	
	SignalBus.on_unit_move_issued.disconnect(_on_unit_move)
	SignalBus.on_unit_move_canceled.disconnect(_on_unit_move)
	SignalBus.on_destination_reached.disconnect(_on_unit_move)

func _on_unit_move(unit:Unit, target:Vector3) -> void:
	if not unit.is_on_team(team):
		return
	
	var unit_id:int = unit.get_instance_id()
	var unit_state: UnitState = _unit_state_dict.get(unit_id)
	if not unit_state:
		push_error("%s: unit=%s did not have unit_added triggered before first command!" % [name, unit.name])
		return
	
	unit_state.time = GameManager.game_timer.time_seconds
	unit_state.move_target = target
		
func _on_unit_added(unit:Unit) -> void:
	if not unit.is_on_team(team):
		return
		
	var state := UnitState.new()
	state.unit = unit
	state.time = GameManager.game_timer.time_seconds
	
	_unit_state_dict[unit.get_instance_id()] = state

func _on_command(unit:Unit, command:StringName, command_id:int, args:Dictionary[StringName,Variant], state:StringName) -> void:
	if not unit.is_on_team(team):
		return
		
	var unit_id:int = unit.get_instance_id()
	var unit_state: UnitState = _unit_state_dict.get(unit_id)
	if not unit_state:
		push_error("%s: unit=%s did not have unit_added triggered before first command!" % [name, unit.name])
		return
	
	unit_state.time = GameManager.game_timer.time_seconds
	unit_state.command_id = command_id
	unit_state.command = command
	unit_state.state = state
	unit_state.args = args

func _on_tick() -> void:
	if not is_visible_in_tree():
		return
	
	_lines.clear()
	
	var keys:Array = _unit_state_dict.keys()
	keys.sort()
	
	for id:int in keys:
		if not is_instance_id_valid(id):
			_unit_state_dict.erase(id)
			continue
		var state:UnitState = _unit_state_dict[id]
		var unit:Unit = state.unit
		var line:String = "%s(%.1f): %s(%d-%s) |%s|%s" % [
			unit.name,
			state.time,
			state.command,
			state.command_id,
			state.state,
			_get_move_str(state),
			_get_active_state_string(unit) if state.command_id > 0 else "SPAWNED"
		]
		_lines.push_back(line)
		
	header.text = "TEAM %d : %d units" % [team, _unit_state_dict.size()]
	body.text = "\n".join(_lines)

func _get_active_state_string(unit:Unit) -> String:
	var actions: UnitActions = unit.get_or_add_actions()
	var blackboard:UnitBlackboard = actions.blackboard
	
	if actions.is_idle():
		return "IDLE"
	if actions.is_hold():
		return "HOLD: %s" % unit.global_position
	if actions.is_attacking():
		var attack_target:Unit = actions.get_attack_target()
		return "ATTACK(%s): %s" % ["M" if actions.is_moving() else "S", \
		 str(attack_target.name) if is_instance_valid(attack_target) else _get_target_str(unit, blackboard.target_position)]
	return ""
		
func _get_move_str(unit_state:UnitState) -> String:
	var move_target := unit_state.move_target
	if move_target.is_equal_approx(Vector3.INF):
		return ""
	return _get_target_str(unit_state.unit, move_target)
	
func _get_target_str(unit:Unit, pos:Vector3) -> String:
	var unit_pos:Vector3 = unit.global_position
	var dist:float = unit_pos.distance_to(pos)
	return "M -> %.1fm" % dist
