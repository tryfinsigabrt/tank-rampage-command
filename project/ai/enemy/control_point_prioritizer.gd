extends Node

@onready var rate_limiter: RateLimiter = $RateLimiter
@onready var tick: Timer = $Tick

func _on_blackboard_on_control_point_discovered(_control_point: ControlPoint) -> void:
	tick.start()
	await _evaluate_priorities()

func _evaluate_priorities() -> void:
	var process := await rate_limiter.limit()
	if not process:
		return
	print_debug("%s: Evaluate Priorities" % name)
