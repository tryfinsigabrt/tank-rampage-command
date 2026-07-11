class_name UnitDirectiveBlackboard extends Blackboard

var _data_keys:Array

class Keys:
	const Action:StringName = "action"
	const Position:StringName = "POSITION"
	const TIME:StringName = "TIME"
	const BOUNDS:StringName = "BOUNDS"
	const Position_Callback:StringName = "POSITION_CALLBACK"
	const CONTROL_POINT:StringName = "CONTROL_POINT"
	const AssetLoad:String = "ASSET_LOAD"
	
var current_action:StringName:
	get:
		return get_value(Keys.Action,&"")
		
var position:Vector3:
	get:
		return get_value(Keys.Position, Vector3.INF)

var bounds:BoundingSphere:
	get:
		return get_value(Keys.BOUNDS)
		
var time:float:
	get:
		return get_value(Keys.TIME, -INF)
		
var control_point:ControlPoint:
	get:
		var instance:Variant = get_value(Keys.CONTROL_POINT)
		return instance as ControlPoint if is_instance_valid(instance) else null

var asset_load:Node3D:
	get:
		var instance:Variant = get_value(Keys.AssetLoad)
		return instance as Node3D if is_instance_valid(instance) else null
		
func set_state(state:AiUnitDirectives.State) -> void:
	clear_state()
	
	set_value(Keys.Action, state.key)
	
	var data := state.data
	for key in data:
		set_value(key, data[key])
	_data_keys = state.data.keys()

func execute_position_callback() -> void:
	var callable:Callable = get_value(Keys.Position_Callback)
	var new_position:Vector3 = callable.call()
	update_state_data(Keys.Position, new_position)
		
func set_load_into_target(asset:Node3D) -> void:
	update_state_data(Keys.AssetLoad, asset)
	
func update_state_data(key:StringName, value:Variant) -> void:
	if not key in _data_keys:
		_data_keys.push_back(key)
	set_value(key, value)
	
func clear_state() -> void:
	erase_value(Keys.Action)
	
	if _data_keys:
		for key:StringName in _data_keys:
			erase_value(key)
		_data_keys.clear()
