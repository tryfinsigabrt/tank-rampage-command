class_name EnumUtils

## Gets the string value of an enum
## By default str(MyEnum.VALUE1) would print 0. Use this function to print "VALUE1"
## printing the enum constant as a string literal
static func enum_to_string(enum_type:Dictionary, enum_value:int) -> StringName:
	return enum_type.keys()[enum_value]

## Attempts to parse an enum string as an enum constant and returns null if there is no match
static func enum_from_string(enum_type:Dictionary, enum_name:StringName, case_sensitive:bool = true) -> Variant:
	var index:int = enum_type.keys().find(enum_name) if case_sensitive else enum_type.keys().find_custom(func(v:StringName) -> bool: return v.nocasecmp_to(enum_name) == 0)
	return enum_type.values()[index] if index != -1 else null

## Returns the ordinal or index of the enum_value within enum_type
## enum Animal { DOG = 3, CAT = 5, RHINO = 7 } # Animal.RHINO returns 2
static func enum_ordinal(enum_type:Dictionary, enum_value:int) -> int:
	return enum_type.values().find(enum_value)

## Returns the enum corresponding to the ordinal int index of the enum returned from enum_ordinal
static func ordinal_to_enum(enum_type:Dictionary, ordinal:int) -> Variant:
	return enum_type.values()[ordinal] if ordinal >= 0 and ordinal < enum_type.values().size() else null

## Returns the enum value as an int
## enum Animal { DOG = 3, CAT = 5, RHINO = 7 } # Animal.RHINO returns 7
static func enum_as_int(enum_value:Variant) -> int:
	return enum_value as int

static func enums_from_strings(enum_type:Dictionary, enum_names: Array, out_enum_values: Array) -> Array:
	out_enum_values.resize(enum_names.size())
	for i in enum_names.size():
		var enum_name:String = enum_names[i]
		var enum_value:Variant = enum_from_string(enum_type, enum_name, false)
		out_enum_values[i] = enum_value
		if enum_value == null:
			push_error("EnumUtils: Unable to map %s to an enum constant of type %s" % [enum_name, str(enum_type)])
			out_enum_values.resize(out_enum_values.size() - 1)
	return out_enum_values
