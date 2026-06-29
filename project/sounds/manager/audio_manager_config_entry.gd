class_name AudioManagerConfigEntry extends Resource

# Cannot assign bus_name to a group since it's dynamic so keep audio_group_name top level too
# This dynamically gets populated as an exported enum property with the available audio buses
var bus_name: String = "Master"

## Additional unique identifier other than the bus_name to identify the unique stream pool.
@export
var group:String

@export_range(1,100,1)
var max_concurrency:int = 5

# Update bus_name dynamically as an exported property
func _get_property_list() -> Array[Dictionary]:
	return [EditorUtils.get_audio_bus_selection_property("bus")]
	

## Unique key for the audio pool	
var key:String:
	get: return "%s_%s" % [bus_name, group] if group else bus_name
	
