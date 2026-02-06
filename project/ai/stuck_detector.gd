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

func _ready() -> void:
	if not unit:
		push_error("%s: Unit not configured" % name)
		return
	_min_dist_sq = min_distance * min_distance
	_samples.resize(max_samples)
	
func reset() -> void:
	_last_target_time = -1.0
	_last_target = Vector3.ZERO
	
	_time = 0
	_last_sample_time = 0
	
	_sample_index = 0
	_num_samples = 0
	
func sample(delta: float, current_position:Vector3, next_target:Vector3) -> bool:
	return true

## Adds a sample and determines if it is currently triggering a stuck condition
func _add_sample(position:Vector3) -> bool:
	return true
