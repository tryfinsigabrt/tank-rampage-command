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

func clone() -> BoundingSphere:
	return BoundingSphere.new(center, radius)

func expand(radius_increase:float) -> void:
	self.radius += radius_increase

func move_to(new_center:Vector3) -> void:
	self.center = new_center
				
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

func overlaps(other: BoundingSphere) -> bool:
	if not other:
		return false
		
	var center_dist: float = center.distance_to(other.center)
	var radial_sum:float = radius + other.radius
	
	return radial_sum <= center_dist

func ray_intersects(ray_origin:Vector3, ray_direction: Vector3) -> bool:
	var to_center:Vector3 = center - ray_origin
	var center_alignment:float = to_center.dot(ray_direction)
	
	# Ray points away from sphere:
	if center_alignment < 0.0:
		return false
		
	var dist_sq:float = to_center.length_squared() - center_alignment * center_alignment
	var radius_sq:float = radius * radius
	
	return dist_sq <= radius_sq

func union(other: BoundingSphere) -> BoundingSphere:
	if not other:
		return clone()

	var delta: Vector3 = other.center - center
	var dist: float = delta.length()

	# Same center: choose the larger sphere.
	if is_zero_approx(dist):
		return BoundingSphere.new(center, maxf(radius, other.radius))

	# One sphere fully contains the other.
	if radius >= dist + other.radius:
		return clone()
	if other.radius >= dist + radius:
		return other.clone()

	var direction: Vector3 = delta / dist
	var new_radius: float = (dist + radius + other.radius) * 0.5
	var new_center: Vector3 = center + direction * (new_radius - radius)

	return BoundingSphere.new(new_center, new_radius)
