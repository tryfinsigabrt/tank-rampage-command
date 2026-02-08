class_name StringUtils

static func parse_bool(value: Variant) -> bool:
	return str(value).to_lower() == "true"
	
static func safe_name(value: Node) -> StringName:
	return value.name if is_instance_valid(value) else &"<null>"
