class_name BoundingCircle

var center:Vector2:
	get:
		return center
		
var radius:float:
	get:
		return radius
	
static func from_sphere(bounding_sphere: BoundingSphere) -> BoundingCircle:
	return BoundingCircle.new(MathUtils.grid_vector(bounding_sphere.center), bounding_sphere.radius)
	
static func from_bounds(bounds:Bounds, is_circumscribed:bool) -> BoundingCircle:
	return from_aabb(bounds.aabb, is_circumscribed)
	
static func from_aabb(aabb:AABB, is_circumscribed:bool) -> BoundingCircle:
	var circle_radius:float = Bounds.calculate_circumscribed_radius_2d(aabb) if is_circumscribed else Bounds.calculate_inscribed_radius_2d(aabb)
	return BoundingCircle.new(MathUtils.grid_vector(aabb.get_center()), circle_radius)
	
func _init(in_center:Vector2, in_radius: float) -> void:
	replace_with(in_center, in_radius)
	
func replace_with(in_center:Vector2, in_radius: float) -> void:
	self.center = in_center
	self.radius = in_radius
	
func distance_to(point:Vector2) -> float:
	var center_dist:float = center.distance_to(point)
	var dist:float = center_dist - radius
	return dist if dist >= 0 else 0.0

func distance_to_bounds(other: BoundingCircle) -> float:
	if not other:
		return INF

	var center_dist: float = center.distance_to(other.center)
	return maxf(0.0, center_dist - radius - other.radius)
	
func contains(point:Vector2) -> bool:
	var dist_sq:float = center.distance_squared_to(point)
	return dist_sq <= radius * radius

func closest_point_to(point:Vector2) -> Vector2:
	if contains(point):
		return point
	
	var point_dir:Vector2 = center.direction_to(point)
	return center + point_dir * radius

func furthest_point_to(point:Vector2) -> Vector2:
	var point_dir:Vector2 = center.direction_to(point)
	return center - point_dir * radius
	
func overlaps(other: BoundingCircle) -> bool:
	return distance_to_bounds(other) <= 0.0

func ray_intersects(ray_origin:Vector2, ray_direction: Vector2) -> bool:
	var to_center:Vector2 = center - ray_origin
	var center_alignment:float = to_center.dot(ray_direction)
	
	# Ray points away from sphere:
	if center_alignment < 0.0:
		return false
		
	var dist_sq:float = to_center.length_squared() - center_alignment * center_alignment
	var radius_sq:float = radius * radius
	
	return dist_sq <= radius_sq

func clone() -> BoundingCircle:
	return BoundingCircle.new(center, radius)
	
func expand(radius_increase:float) -> void:
	self.radius += radius_increase
	
func union(other: BoundingCircle) -> BoundingCircle:
	if not other:
		return clone()

	var delta: Vector2 = other.center - center
	var dist: float = delta.length()

	# Circles are concentric, pix largest radius
	if is_zero_approx(dist):
		return BoundingCircle.new(center, maxf(radius, other.radius))

	# One circle fully contains the other, choose larger one
	if radius >= dist + other.radius:
		return clone()
	if other.radius >= dist + radius:
		return other.clone()

	var direction: Vector2 = delta / dist
	var new_radius: float = (dist + radius + other.radius) * 0.5
	var new_center: Vector2 = center + direction * (new_radius - radius)

	return BoundingCircle.new(new_center, new_radius)
	
func is_equal_approx(other: BoundingCircle) -> bool:
	if not other:
		return false
	return is_equal_approx(radius, other.radius) and center.is_equal_approx(other.center)
