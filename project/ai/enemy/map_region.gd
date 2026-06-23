class_name MapRegion

var area:Rect2
var visible:bool
var explored:bool
var navigable:bool
var last_visible_game_time:float
var index:int


func _init(in_index:int, in_area:Rect2) -> void:
	index = in_index
	area = in_area
