extends Control

@export
var team:int = 2

@onready var label: Label = $Label

var _lines:PackedStringArray

func _tick() -> void:
	_lines.clear()
	
	var units: Array[Node] = get_tree().get_nodes_in_group(Groups.Unit)
	var marines: Array[HumanMarineUnit]
	for unit in units:
		if unit is HumanMarineUnit and unit.team == team:
			marines.push_back(unit)
	
	for marine in marines:
		var header:String = "%d:%s - %.1f%%" % [marine.team, marine.name, marine.health_stat.health_fraction * 100.0]
		_lines.push_back(header)
		
		var unit:String = "   Move: velocity=%s; rot=%.1f; rotating=%s; on_floor=%s" % \
		[marine.velocity, marine.rotation_degrees.y, is_instance_valid(marine._aim_at_tween) and marine._aim_at_tween.is_running()\
			, marine.is_on_floor()
		]
		_lines.push_back(unit)
		
		var nav_state:GameUnitNavigation = marine.game_unit_navigation
		var navigation:String = "   Nav: enabled=%s" % nav_state.enabled
		_lines.push_back(navigation)
		
		var unit_actions:UnitActions = marine.get_or_add_actions()
		var unit_action:String = "   Action: %s -> %s" % [unit_actions.enabled, _get_action(unit_actions)]
		_lines.push_back(unit_action)

		var anim:MarineAnimation = marine.animation
		var animation:String = "   Animation: idle=%s; running=%s; shooting=%s; dead=%s" % [anim.idle, anim.running, anim.shooting, anim.dead]
		_lines.push_back(animation)
	
	label.text = "\n".join(_lines)

func _get_action(unit_actions:UnitActions) -> String:
	if unit_actions.is_idle():
		return "IDLE"
	if unit_actions.is_attacking():
		return "MOVE_AND_ATTACK" if unit_actions.is_moving() else "ATTACK"
	if unit_actions.is_moving():
		return "MOVE"
	return ""
