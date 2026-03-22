class_name Bounds

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
		
func _init(in_aabb:AABB) -> void:
	self.aabb = in_aabb
	
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
