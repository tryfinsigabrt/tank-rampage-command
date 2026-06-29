# Needed for dynamic bus_name discovery in editor through _get_property_list
@tool
class_name AudioManagerConfigEntry extends Resource

enum Type
{
	None = 0,
	PlayerNonSpatial = 1,
	# 2D not currently needed but can be added later
	# Player2D = 2,
	Player3D = 3,
}

@export
var type:Type

# Cannot assign bus_name to a group since it's dynamic so keep audio_group_name top level too
# This dynamically gets populated as an exported enum property with the available audio buses
var bus: String = "Master"

## Additional unique identifier other than the bus_name to identify the unique stream pool.
@export
var group:String

@export_range(1,100,1)
var max_concurrency:int = 5

func _init() -> void:
	# Forces the editor to look at our custom property list right away
	if Engine.is_editor_hint():
		notify_property_list_changed()
		
# Update bus_name dynamically as an exported property
func _get_property_list() -> Array[Dictionary]:
	return [EditorUtils.get_audio_bus_selection_property("bus")]
	
## Unique key for the audio pool	
var key:String:
	get: return create_key(bus, type, group)

var bus_only_key:String:
	get: return create_key(bus, type)

static func create_key(in_bus_name:String, in_type:Type, in_group:String = "") -> String:
	return "%s_%d_%s" % [in_bus_name, in_type, in_group] if in_group else "%s_%d" % [in_bus_name, in_type]
