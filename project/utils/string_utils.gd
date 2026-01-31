class_name StringUtils

static func parse_bool(value: Variant) -> bool:
	return str(value).to_lower() == "true"
	
