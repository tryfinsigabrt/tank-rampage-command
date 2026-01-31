class_name TeamUnits extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

var _units:Array[Unit]

var units:Array[Unit]:
	get: return _units

func add_unit(unit:Unit) -> void:
	_units.push_back(unit)
	unit.tree_exited.connect(_on_unit_destroyed.bind(unit))
	
func _ready() -> void:
	pass

func _on_unit_destroyed(unit:Unit) -> void:
	_units.erase(unit)


func get_average_position() -> Vector3:
	if not units:
		return Vector3.ZERO
		
	var position:Vector3 = Vector3.ZERO
	
	for unit in units:
		position += unit.global_position
	
	return position / units.size()
