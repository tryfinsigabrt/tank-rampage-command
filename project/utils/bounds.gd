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
		
func _init(in_aabb:AABB, in_type:Bounds.Type = Bounds.Type.AABB) -> void:
	self.aabb = in_aabb
	self.type = in_type
	
func _calculate_inscribed_radius() -> float:
	# Sphere needs to fit inside shortest extent
	return aabb.get_shortest_axis_size() * 0.5

func _calculate_circumscribed_radius() -> float:
	# Pythagorean distance of the half extents or half the full extents (size)
	return aabb.size.length() * 0.5

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
