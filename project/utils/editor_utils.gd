class_name EditorUtils

static func get_audio_bus_selection_property(property_name:String) -> Dictionary:
	var buses:Array[String] = []
	var bus_count := AudioServer.bus_count
	for i in bus_count:
		buses.append(AudioServer.get_bus_name(i))
	
	return {
		"name": property_name,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(buses),
		"usage": PROPERTY_USAGE_DEFAULT
	}
	
static func get_input_actions_selection_property(property_name:String) -> Dictionary:
	# Note that InputMap.get_actions() does not return the project setting inputs in an editor tool
	var actions := _get_input_actions()

	return {
		"name": property_name,
		"type": TYPE_STRING_NAME,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(actions),
		"usage": PROPERTY_USAGE_DEFAULT
	}

static func _get_input_actions() -> Array:
	# Note that InputMap.get_actions() does not return the project setting inputs in an editor tool
	var actions := []
	var props: Array[Dictionary] = ProjectSettings.get_property_list()

	for prop in props:
		var name: String = prop["name"]
		if name.begins_with("input/"):
			var action_name := name.trim_prefix("input/")
			if not action_name.begins_with("ui_"):
				actions.push_back(action_name)
	
	actions.sort()
	
	return actions
	
static func get_input_actions_array_selection_property(property_name: String) -> Dictionary:
	var actions := _get_input_actions()

	return {
		"name": property_name,
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [TYPE_STRING_NAME, PROPERTY_HINT_ENUM, ",".join(actions)],
		"usage": PROPERTY_USAGE_DEFAULT
	}
