class_name Bounds

enum Type
{
	AABB,
	SPHERE_INSCRIBED,
	SPHERE_CIRCUMSCRIBED
}

var type:Bounds.Type = Bounds.Type.AABB

var aabb:AABB:
	get:
		return aabb

var inscribed_sphere:BoundingSphere:
	get:
		if not inscribed_sphere:
			inscribed_sphere = BoundingSphere.new(aabb.get_center(), _calculate_inscribed_radius())
		return inscribed_sphere

var circumscribed_sphere:BoundingSphere:
	get:
		if not circumscribed_sphere:
			circumscribed_sphere = BoundingSphere.new(aabb.get_center(), _calculate_circumscribed_radius())
		return circumscribed_sphere
	
var radius:float:
	get:
		match type:
			Type.SPHERE_INSCRIBED:
				return inscribed_sphere.radius
			Type.SPHERE_CIRCUMSCRIBED:
				return circumscribed_sphere.radius
			_:
				return aabb.get_longest_axis_size() * 0.5
			
func _init(in_aabb:AABB, in_type:Bounds.Type = Bounds.Type.AABB) -> void:
	self.aabb = in_aabb
	self.type = in_type
	
func _calculate_inscribed_radius() -> float:
	# Sphere needs to fit inside shortest extent
	return aabb.get_shortest_axis_size() * 0.5

func _calculate_circumscribed_radius() -> float:
	# Pythagorean distance of the half extents or half the full extents (size)
	return aabb.size.length() * 0.5
	
static func calculate_inscribed_radius_2d(in_aabb:AABB) -> float:
	var grid_vector:Vector2 = MathUtils.grid_vector(in_aabb.size)
	return minf(grid_vector.x, grid_vector.y) * 0.5

static func calculate_circumscribed_radius_2d(in_aabb:AABB) -> float:
	var grid_vector:Vector2 = MathUtils.grid_vector(in_aabb.size)
	return grid_vector.length() * 0.5

static func create_circumscribed_sphere(in_aabb:AABB) -> BoundingSphere:
	return Bounds.new(in_aabb,Bounds.Type.SPHERE_CIRCUMSCRIBED).circumscribed_sphere
	
static func create_inscribed_sphere(in_aabb:AABB) -> BoundingSphere:
	return Bounds.new(in_aabb,Bounds.Type.SPHERE_INSCRIBED).inscribed_sphere
	
func replace_with(in_aabb:AABB) -> void:
	if in_aabb.is_equal_approx(aabb):
		return
		
	self.aabb = in_aabb
	if inscribed_sphere:
		inscribed_sphere.replace_with(aabb.get_center(), _calculate_inscribed_radius())
	if circumscribed_sphere:
		circumscribed_sphere.replace_with(aabb.get_center(), _calculate_circumscribed_radius())

func distance_to(point:Vector3) -> float:
	if type == Type.AABB:
		var closest_point := closest_point_to(point)	
		return point.distance_to(closest_point)
		
	var sphere:BoundingSphere = inscribed_sphere if type == Type.SPHERE_INSCRIBED else circumscribed_sphere
	return sphere.distance_to(point)	

func distance_to_bounds(other: Bounds) -> float:
	if not other:
		return INF

	if type != Type.AABB and other.type != Type.AABB:
		return _get_active_sphere().distance_to_bounds(other._get_active_sphere())

	if type == Type.AABB and other.type == Type.AABB:
		return _distance_between_aabbs(aabb, other.aabb)

	if type == Type.AABB:
		return _distance_between_aabb_and_sphere(aabb, other._get_active_sphere())

	return _distance_between_aabb_and_sphere(other.aabb, _get_active_sphere())

func overlaps(other: Bounds) -> bool:
	return distance_to_bounds(other) <= 0.0

func _get_active_sphere() -> BoundingSphere:
	return inscribed_sphere if type == Type.SPHERE_INSCRIBED else circumscribed_sphere

static func _distance_between_aabbs(left: AABB, right: AABB) -> float:
	var dx: float = maxf(0.0, maxf(left.position.x - right.end.x, right.position.x - left.end.x))
	var dy: float = maxf(0.0, maxf(left.position.y - right.end.y, right.position.y - left.end.y))
	var dz: float = maxf(0.0, maxf(left.position.z - right.end.z, right.position.z - left.end.z))
	return Vector3(dx, dy, dz).length()

static func _distance_between_aabb_and_sphere(box: AABB, sphere: BoundingSphere) -> float:
	var closest := Vector3(
		clampf(sphere.center.x, box.position.x, box.end.x),
		clampf(sphere.center.y, box.position.y, box.end.y),
		clampf(sphere.center.z, box.position.z, box.end.z)
	)
	return maxf(0.0, closest.distance_to(sphere.center) - sphere.radius)
	
func closest_point_to(point:Vector3) -> Vector3:
	if type == Type.AABB:
		if contains(point):
			return point
		# Find the closest point on the AABB
		var pos := aabb.position
		var end := aabb.end
		var closest_point := Vector3(
			clampf(point.x, pos.x, end.x),
			clampf(point.y, pos.y, end.y),
			clampf(point.z, pos.z, end.z)
		)
		return closest_point
		
	var sphere:BoundingSphere = inscribed_sphere if type == Type.SPHERE_INSCRIBED else circumscribed_sphere
	return sphere.closest_point_to(point)
	
func contains(point:Vector3) -> bool:
	if type == Type.AABB:
		return aabb.has_point(point)
	
	var sphere:BoundingSphere = inscribed_sphere if type == Type.SPHERE_INSCRIBED else circumscribed_sphere
	return sphere.contains(point)

func is_equal_approx(other:Bounds) -> bool:
	if not other:
		return false
	if self == other:
		return true
	if self.type != other.type:
		return false
	return aabb.is_equal_approx(other.aabb)
	
func to_rect() -> Rect2:
	return aabb_to_grid_rect(aabb)
	
static func aabb_to_grid_rect(bounds:AABB) -> Rect2:
	var pos:Vector3 = bounds.position
	var size:Vector3 = bounds.size
	
	return Rect2(Vector2(pos.x, pos.z), Vector2(size.x, size.z))
