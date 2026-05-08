class_name PersonnelResource extends Resource

signal cap_changed(old_value:int, new_value:int)
signal count_changed(old_value:int, new_value:int)
signal reserve_count_changed(old_value:int, new_value:int)

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
		# If already over the max don't clamp down
		count = clampi(value, 0, maxi(prev_value, cap))
		
		if prev_value != count:
			if count > prev_value:
				if reserved_count <= cap:
					reserved_count = maxi(count, reserved_count)
				# Clamp down to current count
				else:
					reserved_count = count
			else:
				# Free up reserved by decrease in count
				reserved_count -= prev_value - count
				
			count_changed.emit(prev_value, count)

var reserved_count:int:
	set(value):
		var prev_value := reserved_count
		# If already over the max don't clamp down
		reserved_count = clampi(value, 0, maxi(prev_value, cap))
		
		if prev_value != count:
			reserve_count_changed.emit(prev_value, reserved_count)
	get:
		return maxi(reserved_count, count)
				
var remaining:int:
	get:
		return cap - reserved_count
