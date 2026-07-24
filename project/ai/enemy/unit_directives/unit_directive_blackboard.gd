class_name UnitDirectiveBlackboard extends Blackboard

var _data_keys:Array

class Keys:
	const Action:StringName = "action"
	const Position:StringName = "POSITION"
	const TargetNode:StringName = "TARGET_NODE"
	const TIME:StringName = "TIME"
	const BOUNDS:StringName = "BOUNDS"
	const Position_Callback:StringName = "POSITION_CALLBACK"
	const CONTROL_POINT:StringName = "CONTROL_POINT"
	const AssetLoad:String = "ASSET_LOAD"
	const LoadUnits:String = "LOAD_UNITS"
	const TargetState:String = "TARGET_STATE"
	const HeadingBias:String = "HEADING_BIAS"
	
var current_action:StringName:
	get:
		return get_value(Keys.Action,&"")
		
var position:Vector3:
	get:
		return get_value(Keys.Position, Vector3.INF)

var target_node:Node3D:
	get:
		var instance:Variant = get_value(Keys.TargetNode)
		return instance as Node3D if is_instance_valid(instance) else null
		
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

var load_units:Array[Unit]:
	get:
		var unit_ids:PackedInt64Array = get_value(Keys.LoadUnits, PackedInt64Array())
		var units:Array[Unit]
		units.resize(unit_ids.size())
		var count:int = 0
		for id in unit_ids:
			var unit:Unit = instance_from_id(id) as Unit
			if unit:
				units[count] = unit
				count += 1
		if count != units.size():
			units.resize(count)
		
		return units
var target_state:AiUnitDirectives.State:
	get:
		return get_value(Keys.TargetState)

var heading_bias:Vector3:
	get:
		return get_value(Keys.HeadingBias, Vector3.ZERO)
				
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
	if key not in _data_keys:
		_data_keys.push_back(key)
	set_value(key, value)
	
func clear_state() -> void:
	erase_value(Keys.Action)
	
	if _data_keys:
		for key:StringName in _data_keys:
			erase_value(key)
		_data_keys.clear()
