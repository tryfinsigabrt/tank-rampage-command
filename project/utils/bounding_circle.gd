class_name BoundingCircle

var center:Vector2:
	get:
		return center
		
var radius:float:
	get:
		return radius
	
func _init(in_center:Vector2, in_radius: float) -> void:
	replace_with(in_center, in_radius)
	
func replace_with(in_center:Vector2, in_radius: float) -> void:
	self.center = in_center
	self.radius = in_radius
	
func distance_to(point:Vector2) -> float:
	var center_dist:float = center.distance_to(point)
	var dist:float = center_dist - radius
	return dist if dist >= 0 else 0.0

func contains(point:Vector2) -> bool:
	var dist_sq:float = center.distance_squared_to(point)
	return dist_sq <= radius * radius

func closest_point_to(point:Vector2) -> Vector2:
	if contains(point):
		return point
	
	var point_dir:Vector2 = center.direction_to(point)
	return center + point_dir * radius
