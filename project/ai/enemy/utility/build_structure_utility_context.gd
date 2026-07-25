class_name BuildStructureUtilityContext extends AbstractBuildPlacementUtilityContext

const CONTAINER_PREFIX:String = "container."

var need_score:float
var required_strength:float

# Will be used by bunker type to make sure there are units that can fill the bunker
var available_infantry_units:int	

# Not currently required but adding in case we have structures that require personnel
var available_personnel:int

# Count of this type in inventory or in progress of building
var unused_count:int

var container:ContainerUtility

# Resolve container property names
func _get(property: StringName) -> Variant:
	if property.begins_with(CONTAINER_PREFIX):
		return container.get(property.substr(CONTAINER_PREFIX.length()))
	# Invoke default behavior of "get" for normal property names
	return null
