class_name EnemyVisibilityManager extends Node

@onready var team_units: TeamUnits = %TeamUnits

var _visible_units:Dictionary[int,bool] = {}

var visible_units:Array[Unit]:
	get:
		var units:Array[Unit]
		for unit_id in _visible_units:
			var unit:Unit = instance_from_id(unit_id)
			if unit:
				units.push_back(unit)
		return units
		
func _ready() -> void:
	team_units.enemy_visibility_changed.connect(_on_enemy_visibility_changed)

func _on_enemy_visibility_changed(enemy:Unit, enemy_visibility:bool) -> void:
	if enemy_visibility:
		_visible_units[enemy.get_instance_id()] = true
	else:
		_visible_units.erase(enemy.get_instance_id())
