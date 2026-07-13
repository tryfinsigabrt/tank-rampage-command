# Needed for dynamic bus_name discovery in editor through _get_property_list
@tool
class_name AudioPlayerConfig extends Resource

@export
var stream_config:AudioStreamConfig

# Cannot assign bus_name to a group since it's dynamic so keep audio_group_name top level too
# This dynamically gets populated as an exported enum property with the available audio buses
var bus: String = "Master"

## Additional unique identifier other than the bus_name to identify the unique stream pool.
## If the group doesn't exist on the audio manager, then a warning will be emitted the first time and the bus group will be used
@export
var group:String

@export
var attenuation_model:AudioStreamPlayer3D.AttenuationModel = AudioStreamPlayer3D.AttenuationModel.ATTENUATION_INVERSE_DISTANCE

@export_range(-80.0, 80.0, 0.01)
var volume_db:float = 0.0

@export_range(-80.0, 80.0, 0.01)
var volume_max_db:float = 3.0

@export_range(0.01, 4.0, 0.01)
var pitch_scale:float = 1.0

@export_range(0.0, 1e9, 0.01, "or_greator")
var max_distance:float

@export_range(0.01, 1e9, 0.01, "or_greater")
var unit_size:float = 500.0

## Indicate whether the player should be paused when the game is paused
## false aligns with the default root node behavior that uses Node.ProcessMode value of PROCESS_MODE_PAUSABLE
## true aligns with PROCESS_MODE_ALWAYS.

@export
var play_when_paused:bool = false

var valid: bool:
	get: return stream_config and stream_config.stream

func _init() -> void:
	# Forces the editor to look at our custom property list right away
	if Engine.is_editor_hint():
		notify_property_list_changed()
		
# Update bus_name dynamically as an exported property
func _get_property_list() -> Array[Dictionary]:
	return [EditorUtils.get_audio_bus_selection_property("bus")]
	
