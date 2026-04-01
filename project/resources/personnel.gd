class_name PersonnelResource extends Resource

@export_range(1,1e9,1, "or_greater")
var cap:int = 10

@export
var count:int:
	set(value):
		count = clampi(value, 0, cap)

var remaining:int:
	get:
		return cap - count
