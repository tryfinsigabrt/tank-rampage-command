class_name PersonnelResource extends Resource

signal cap_changed(old_value:int, new_value:int)
signal count_changed(old_value:int, new_value:int)

@export_range(1,1e9,1, "or_greater")
var control_point_cap_bonus:int = 10

@export_range(1,1e9,1, "or_greater")
var cap:int = 10:
	set(value):
		var prev_value := cap
		if value == prev_value:
			return
			
		cap = value
		cap_changed.emit(prev_value, value)

@export
var count:int:
	set(value):
		var prev_value := count
		count = clampi(value, 0, cap)
		
		if prev_value != count:
			count_changed.emit(prev_value, count)

var remaining:int:
	get:
		return cap - count
