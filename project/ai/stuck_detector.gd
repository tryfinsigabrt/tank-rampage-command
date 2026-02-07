## Detects if a unit is stuck and broadcasts a signal if this happens
class_name StuckDetector extends Node

signal stuck

@export_range(10,1000)
var max_samples:int = 100

@export_range(10,1000)
var min_samples:int = 50

@export
var sampling_rate:float = 0.1

@export
var max_same_target_time:float = 20.0

@export
var min_stuck_time:float = 8.0

@export_range(0.1, 1e9, 0.1, "or_greater")
var min_distance:float = 1.0

var unit:Unit

var _min_dist_sq:float
var _last_target_time:float
var _last_target:Vector3
var _time:float
var _last_sample_time:float
var _last_stuck_time:float
var _sample_index:int
var _samples:PackedVector3Array
var _num_samples:int

var _goal_position:Vector3

var goal_position:Vector3:
	get:
		return _goal_position
	set(value):
		if not value.is_equal_approx(goal_position):
			reset()
			_goal_position = value

func _ready() -> void:
	_min_dist_sq = min_distance * min_distance
	_samples.resize(max_samples)
	reset()
	
func reset() -> void:
	_goal_position = Vector3.ZERO
	
	_last_target_time = -1.0
	_last_target = Vector3.ZERO
	
	_time = 0
	# Force first sample to store
	_last_sample_time = -sampling_rate
	_last_stuck_time = -1.0
	
	_sample_index = 0
	_num_samples = 0
	
func sample(delta: float, current_position:Vector3, next_target:Vector3) -> bool:
	var last_time:float = _time
	_time += delta
	
	var last_sample_dt:float = last_time - _last_sample_time
	if last_sample_dt < sampling_rate:
		return true
		
	if _last_target_time < 0 or not next_target.is_equal_approx(_last_target):
		_last_target_time = last_time
		_last_target = next_target
	# Check if we've been on this target for too long and aren't making progress toward the goal
	elif last_time - _last_target_time > max_same_target_time:
		print("%s: unit=%s at pos=%s on same target=%s for > %.1fs" % [name, unit, current_position, next_target, max_same_target_time])
		stuck.emit()
		return false
	
	var not_stuck:bool = _add_sample(current_position)
	if not_stuck:
		_last_stuck_time = -1.0
		return true
	
	# Check how long we've been stuck
	if _last_stuck_time < 0:
		_last_stuck_time = last_time
		return true
	if last_time - _last_stuck_time >= min_stuck_time:
		print("%s: unit=%s at pos=%s with target=%s has been stuck for > %.1fs" % [name, unit, current_position, next_target, min_stuck_time])
		stuck.emit()
		# Avoid retrigger
		_last_stuck_time = -1.0
		return false
	return true

## Adds a sample and determines if it is currently triggering a stuck condition
func _add_sample(position:Vector3) -> bool:
	var current_index := _sample_index
	var first_index:int = 0
	
	_samples[current_index] = position

	if _num_samples < max_samples:
		_num_samples = _num_samples + 1
		_sample_index = _num_samples % max_samples
		if _num_samples < min_samples:
			return true
	else:
		_sample_index = (_sample_index + 1) % max_samples
		# When we've wrapped, the first index is the next one to be overwritten
		first_index = _sample_index
		
	# Compute total distance
	var dist_sq:float = position.distance_squared_to(_samples[first_index])
	return dist_sq >= _min_dist_sq
	
