@tool
extends CommandActionLeaf

@export
var new_threat_min_distance_threshold:float = 200.0

@export
var threat_max_distance_threshold:float = 500.0

@export
var threat_scorer:ThreatScorer

var _unit:Unit
var _target_position:Vector3 = Vector3.INF
var _finished:int = 0
var _destination_reached:bool

var _attack_action:AttackAction
var _scanner:UnitScanner

const attack_action_scene = preload("uid://cwj8iaowhbop5")
const scanner_scene = preload("uid://8rwv0t451365")

func _cleanup(actor: Node, blackboard: UnitBlackboard) -> void:
	#print_debug("%s: CLEANUP %s - command %d -> %s AFTER RUN" % [name, actor.name, action_id, my_action])
	super._cleanup(actor, blackboard)
	if is_instance_valid(_attack_action):
		_attack_action.queue_free()
		_attack_action = null
	if is_instance_valid(_scanner):
		_scanner.queue_free()
		_scanner = null
	if not _finished:
		SignalBus.on_unit_move_canceled.emit(actor as Unit, _target_position)
		_target_position = Vector3.INF
		_disconnect_move_signal()
	
func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	
	_finished = 0
	_destination_reached = false
	
	_unit = actor as Unit
	if not _unit or not blackboard.has_value(UnitBlackboard.Keys.TargetPosition):
		_finished = -1
		push_error("%s: Missing current unit or target position - cannot perform attack action" % name)
		return
		
	_target_position = blackboard.get_value(UnitBlackboard.Keys.TargetPosition) as Vector3

	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(_target_position, 5.0, Color.ORANGE, 3.0)
		
	_scanner = scanner_scene.instantiate()
	_scanner.my_unit = _unit
	var weapon := _unit.weapon
	if weapon:
		threat_max_distance_threshold = maxf(threat_max_distance_threshold, weapon.ideal_fire_range.y)
		
	_scanner.threshold_distance = threat_max_distance_threshold
	_scanner.threats_detected.connect(_threats_detected)
	add_child(_scanner)

	_connect_move_signal()
	SignalBus.on_unit_move_issued.emit(_unit, _target_position)

func _threats_detected(threats:Array[Node3D]) -> void:
	print_debug("%s: %d threats detected" % [name, threats.size()])		
	# If currently engaging a threat, don't stop unless new threat is much closer
	
	var unit_position:Vector3 = _unit.global_position
	var ranked_threats: Array[UnitScore] = threat_scorer.get_threat_assets(threats, unit_position)
	if not ranked_threats:
		print_debug("%s: No credible threats to attack" % name)
		return
		
	var top_threat:UnitScore = ranked_threats.front()

	if is_instance_valid(_attack_action) and _attack_action.is_valid() and _attack_action.firing:
		var top_threat_distance:float = top_threat.dist
		var current_attack_distance:float = _attack_action.targeted_node.global_position.distance_to(unit_position)
		var distance_diff:float = current_attack_distance - top_threat_distance
		
		# Continue attacking existing threat to avoid thrashing
		if distance_diff < new_threat_min_distance_threshold:
			return
	_attack_asset(top_threat.threat)
	
func _attack_asset(enemy:Node3D) -> void:
	if is_instance_valid(_attack_action):
		_attack_action.queue_free()
		
	_attack_action = attack_action_scene.instantiate()
	_attack_action.controlled_unit = _unit
	_attack_action.targeted_node = enemy
	_attack_action.move_into_range = AttackAction.MoveBehavior.NEVER
	
	_attack_action.tree_exited.connect(func() -> void:
		_attack_action = null
		_check_and_set_finished()
	)

	add_child(_attack_action)
	
func tick(_actor: Node, blackboard: Blackboard) -> int:
	var result:int
	if _finished:
		result = SUCCESS
	else:
		result = _check_running_state(blackboard)

	return result

func _on_destination_reached(unit:Unit, target:Vector3) -> void:
	if unit != _unit:
		return
	
	if LogUtils.verbose:
		print_debug("%s: Move destination reached: %s -> %s" % [name, unit, target])
		
	_disconnect_move_signal()
	_destination_reached = true
	
	_check_and_set_finished()

func _check_and_set_finished() -> void:
	if not _finished and _destination_reached and not is_instance_valid(_attack_action):
		_finished = 1
		
func _connect_move_signal() -> void:
	if not SignalBus.on_destination_reached.is_connected(_on_destination_reached):
		SignalBus.on_destination_reached.connect(_on_destination_reached)

func _disconnect_move_signal() -> void:
	if SignalBus.on_destination_reached.is_connected(_on_destination_reached):
		SignalBus.on_destination_reached.disconnect(_on_destination_reached)

func _should_continue_running(blackboard: Blackboard) -> bool:
	var current_target:Vector3 = blackboard.get_value(UnitBlackboard.Keys.TargetPosition, Vector3.INF)
	return current_target.is_equal_approx(_target_position)

func _get_action_args() -> Dictionary[StringName, Variant]:
	return {
		&"position" : _target_position
	}
