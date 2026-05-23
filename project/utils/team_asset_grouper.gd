class_name TeamAssetGrouper

# For player this is the hotkey 1-0
var _groups:Dictionary[String, Array]

func add_group(group_id:String, objects:Array) -> void:
	_groups[group_id] = objects
	
func has(group_id:String) -> bool:
	return group_id in _groups
	
func remove(group_id:String) -> void:
	_groups.erase(group_id)
	
func get_group(group_id:String) -> Array:
	# Explicitly fail as otherwise we get subtle type conversion issues
	# use "has" to check first if not sure if group exists
	var group:Array = _groups[group_id]
	
	# Remove invalid
	for i in range(group.size() - 1, -1, -1):
		if not is_instance_valid(group[i]):
			group.remove_at(i)

	return group
