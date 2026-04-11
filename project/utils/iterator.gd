class_name Iterator

var keys:Array
var idx:int

func _init(in_keys:Array) -> void:
	keys = in_keys

func get_value() -> Variant:
	return keys[idx]

func increment() -> bool:
	idx += 1
	return has_next()

func has_next() -> bool:
	return idx < keys.size()
	
