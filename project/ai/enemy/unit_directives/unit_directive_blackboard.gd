class_name UnitDirectiveBlackboard extends Blackboard

var _data_keys:Array

class Keys:
	const Action:StringName = "action"
	const Position:StringName = "POSITION"
	const TIME:StringName = "TIME"
	
var current_action:StringName:
	get:
		return get_value(Keys.Action,&"")
		
var position:Vector3:
	get:
		return get_value(Keys.Position, Vector3.INF)

var time:float:
	get:
		return get_value(Keys.TIME, -INF)

func set_state(state:AiUnitDirectives.State) -> void:
	clear_state()
	
	set_value(Keys.Action, state.key)
	
	var data := state.data
	for key in data:
		set_value(key, data[key])
	_data_keys = state.data.keys()
	
func clear_state() -> void:
	erase_value(Keys.Action)
	
	if _data_keys:
		for key:StringName in _data_keys:
			erase_value(key)
		_data_keys.clear()
