class_name AttackAction extends Node3D

var controlled_unit:Unit
var targeted_unit:Unit
var targeted_location:Vector3

# TODO: This will vary per unit so should get the min fire interval from the controlled unit
# and maybe this will be a multiplier on top of that
# Same with the fire range
@export
var fire_interval:float = 2.0

@export
var fire_range:Vector2 = Vector2(0.0, 2000.0)

var _fire_timer:Timer

func _ready() -> void:
	if not controlled_unit:
		push_warning("%s: No controlled unit set - no attack will occur" % name)
		return
		
	_fire_timer = Timer.new()
	_fire_timer.name = &"FireTimer"
	_fire_timer.autostart = false
	_fire_timer.one_shot = false
	_fire_timer.wait_time = fire_interval
	_fire_timer.timeout.connect(_on_fire)
	add_child(_fire_timer)

func _process(_delta: float) -> void:
	if not _is_valid():
		queue_free()
		return
		
	_aim()
	var fire_timer_running:bool = not _fire_timer.is_stopped()
	var in_range:bool = _is_in_range()
	
	if in_range and not fire_timer_running:
		_fire_and_schedule()
	elif not in_range and fire_timer_running:
		_fire_timer.stop()
		
func _aim() -> void:
	var target:Vector3 = _get_target_position()
	controlled_unit.aim_at(target)
	
func _is_in_range() -> bool:
	var my_position:Vector3 = controlled_unit.global_position
	var target_position:Vector3 = _get_target_position()
	var dist_sq:float = my_position.distance_squared_to(target_position)
	
	return dist_sq >= fire_range.x * fire_range.x and dist_sq <= fire_range.y * fire_range.y
	
func _is_target_valid() -> bool:
	return not targeted_unit or is_instance_valid(targeted_unit)
	
func _get_target_position() -> Vector3:
	return targeted_unit.global_position if targeted_unit else targeted_location
	
func _is_valid() -> bool:
	return is_instance_valid(controlled_unit) and _is_target_valid()

func _fire_and_schedule() -> void:
	_fire()
	_fire_timer.start()
	
func _on_fire() -> void:
	if not _is_valid():
		queue_free()
		return
	_fire()

func _fire() -> void:
	controlled_unit.shoot()
