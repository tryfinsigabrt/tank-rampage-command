class_name MoveTracker extends Node

var leader:Unit
var follower:Unit
var follow_forever:bool = true

var _blackboard:Blackboard
var _tracked_leader_command_id:int = -1
var _follower_command_id:int = -1

func _ready() -> void:
	if not is_instance_valid(leader):
		push_error("%s: leader is not valid; follower=%s" % [name, StringUtils.safe_name(follower)])
		queue_free()
		return
	if not is_instance_valid(follower):
		push_error("%s: follower is not valid; leader=%s" % [name, StringUtils.safe_name(leader)])
		queue_free()
		return
	
	var leader_unit_nav:GameUnitNavigation= Groups.get_child_with_type(leader, GameUnitNavigation)
	assert(leader_unit_nav, "%s: Leader unit=%s does not have GameUnitNavigation" % [name, leader.name])
	if not leader_unit_nav:
		queue_free()
		return
	
	var follower_actions := follower.get_or_add_actions()
	_follower_command_id = follower_actions.last_command_id
	
	# Only follow leader until they finish their current action
	if not follow_forever:
		var leader_actions := leader.get_or_add_actions()
		_tracked_leader_command_id = leader_actions.last_command_id
		leader_actions.command_finished.connect(_on_leader_command_finished)
		leader_actions.command_issued.connect(_on_leader_command_issued)
			
	_blackboard = follower_actions.blackboard
	
	leader.died.connect(_on_leader_killed.unbind(1))
	
	leader_unit_nav.move_started.connect(_on_leader_move_started)	
	leader_unit_nav.move_completed.connect(_on_leader_move_finished.unbind(1))	
	leader_unit_nav.move_canceled.connect(_on_leader_move_finished.unbind(1))
	
	# Set initial target
	var initial_target:Vector3 = leader_unit_nav.current_target if leader_unit_nav.enabled else leader.global_position
	_update_target_position(initial_target)

func _on_leader_killed() -> void:
	if not is_instance_valid(follower):
		return
	
	print_debug("%s: Canceling follow command as leader=%s was killed" % [name, StringUtils.safe_name(leader)])
	_stop_following()
	
func _stop_following() -> void:
	# Only issue stop if a new action wasn't issued since we started following
	var follower_actions := follower.get_or_add_actions()
	if follower_actions.last_command_id == _follower_command_id:
		follower_actions.stop()
		
	queue_free()
	
func _on_leader_move_started(target:Vector3) -> void:
	# If new move issued then update move and attack target
	_update_target_position(target)

func _on_leader_move_finished() -> void:
	# Track the leader position
	if is_instance_valid(leader):
		_update_target_position(leader.global_position)

func _update_target_position(target:Vector3) -> void:
	_blackboard.set_value(UnitBlackboard.Keys.TargetPosition, target)

func _on_leader_command_issued(command_id:int) -> void:
	if command_id != _tracked_leader_command_id:
		_stop_following()
		
func _on_leader_command_finished(command_id:int) -> void:
	if command_id == _tracked_leader_command_id:
		_stop_following()
