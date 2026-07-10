class_name TeamAssetAttributes extends Resource

const META_ATTRIBUTE_NAME:StringName = &"TeamAssetAttributes"

## Attack strength of the asset
@export_range(0.0, 1e9, 0.01,"or_greater")
var strength:float = 1.0

## Priority to attack - lower is higher priority
@export_range(0, 1e9, 1, "or_greater")
var attack_priority:int = 0

## Relative strength of required defense of this team asset
## Normally only applies to defenseless high value assets like buildings or transports
@export_range(0.0, 1e9, 0.01, "or_greater")
var defense_strength:float = 0.0

## Ideal range to explore - only applies to units
@export
var explore_range:Vector2 = Vector2(100.0, 250.0)


#region Meta retrieval

func register_with(owner:Node) -> void:
	assert(owner)
	if not owner:
		push_error("register_attributes: owner was null!")
		return
	
	owner.set_meta(META_ATTRIBUTE_NAME, self)

static func has_attributes(node:Node) -> bool:
	return is_instance_valid(node) and node.has_meta(META_ATTRIBUTE_NAME)
		
static func get_attributes(node:Node, required:bool = true) -> TeamAssetAttributes:
	if not required and not has_attributes(node):
		return null
		
	var attrs:TeamAssetAttributes = node.get_meta(META_ATTRIBUTE_NAME) as TeamAssetAttributes
	assert(attrs, "Could not find TeamAssetAttributes %s on node=%s" % [META_ATTRIBUTE_NAME, node.name])
	return attrs
#endregion
