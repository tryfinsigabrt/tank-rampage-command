## Rate limits actions so that limit returns true at most once in a given interval
## If a second request comes in during the interval, then it is emitted at the end of that interval
class_name RateLimiter extends Node

@export
var _interval:float = 0.1

@onready var _timer: Timer = $Timer

var _waiting:bool = false

func _ready() -> void:
	_timer.wait_time = _interval

## Asynchronously returns true if the action should be permitted and false otherwise
func limit() -> bool:
	if _timer.is_stopped():
		_timer.start()
		return true
	# If another event comes in during the timer fire it at the end
	elif not _waiting:
		_waiting = true
		await _timer.timeout
		_waiting = false
		_timer.start()
		return true
	return false
