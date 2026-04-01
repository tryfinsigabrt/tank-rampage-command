class_name ScrapResource extends Resource

signal cap_changed(old_value:int, new_value:int)
signal count_changed(old_value:int, new_value:int)

@export_range(1,1e9,1, "or_greater")
var cap:int = 100000:
	set(value):
		var prev_value := cap
		if value == prev_value:
			return
			
		cap = value
		cap_changed.emit(prev_value, value)

@export
var count:int = 5000:
	set(value):
		var prev_value := count
		count = clampi(value, 0, cap)
		
		if count != prev_value:
			count_changed.emit(prev_value, count)
