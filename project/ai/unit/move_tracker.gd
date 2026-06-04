class_name MoveTracker extends Node

var leader:Unit
var follower:Unit

var _blackboard:Blackboard

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
		
	_blackboard = follower.get_or_add_actions().blackboard
	
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
	follower.get_or_add_actions().stop()
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
