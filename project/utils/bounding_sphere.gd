class_name BoundingSphere

var center:Vector3:
	get:
		return center
var radius:float:
	get:
		return radius
	
func _init(in_center:Vector3, in_radius: float) -> void:
	replace_with(in_center, in_radius)
	
func replace_with(in_center:Vector3, in_radius: float) -> void:
	self.center = in_center
	self.radius = in_radius
	
func distance_to(point:Vector3) -> float:
	var center_dist:float = center.distance_to(point)
	var dist:float = center_dist - radius
	return dist if dist >= 0 else 0.0

func contains(point:Vector3) -> bool:
	var dist_sq:float = center.distance_squared_to(point)
	return dist_sq <= radius * radius

func closest_point_to(point:Vector3) -> Vector3:
	if contains(point):
		return point
	
	var point_dir:Vector3 = center.direction_to(point)
	return center + point_dir * radius
