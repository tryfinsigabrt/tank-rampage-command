class_name ScrapResource extends Resource

@export_range(1,1e9,1, "or_greater")
var cap:int = 100000

@export
var count:int = 5000:
	set(value):
		count = clampi(value, 0, cap)
