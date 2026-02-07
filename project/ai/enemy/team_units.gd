class_name TeamUnits extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@warning_ignore("unused_signal")
signal initialized

var team:int

var _units:Dictionary[int, Unit] = {}
var _unit_values: Array[Unit]
var _dirty:bool

var units_dict:Dictionary[int, Unit]:
	get: return _units
	
var units:Array[Unit]:
	get: return _get_units_array()

func add_unit(unit:Unit) -> void:
	_units[unit.get_instance_id()] = unit
	_dirty = true
	unit.died.connect(_on_unit_destroyed.bind(unit).unbind(1))
	
func has_unit_id(id:int) -> bool:
	return _units.has(id)

func has_unit(unit:Unit) -> bool:
	return is_instance_valid(unit) and has_unit_id(unit.get_instance_id())
	
func _get_units_array() -> Array[Unit]:
	if _dirty:
		_unit_values.resize(_units.size())
		var i:int = 0
		for id in _units:
			_unit_values[i] = _units[id]
			i += 1
		_dirty = false
	return _unit_values
	
func _on_unit_destroyed(unit:Unit) -> void:
	_units.erase(unit.get_instance_id())
	_dirty = true

func get_average_position() -> Vector3:
	if not _units:
		return Vector3.ZERO
		
	var position:Vector3 = Vector3.ZERO
	
	for id in _units:
		var unit:Unit = _units[id]
		position += unit.global_position
	
	return position / _units.size()
