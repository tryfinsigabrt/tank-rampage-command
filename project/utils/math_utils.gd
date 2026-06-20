class_name MathUtils

## Returns a random sign (-1.0 or 1.0)
static func randf_sgn() -> float:
	return signf(randf() - 0.5)

## Returns a random float in the range [min_value, max_value] and then multiplies it by a random sign (-1.0 or 1.0)
static func randf_range_signed(min_value: float, max_value: float) -> float:
	return randf_range(min_value, max_value) * randf_sgn()

static func get_angle_deg_between_points(a:Vector2, b:Vector2) -> float:
	return absf(rad_to_deg(a.angle_to_point(b)))

static func get_rand_vector2_dir() -> Vector2:
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

## Updates the given mask by masking out selector and then applying selection
static func update_mask(mask:int, selector:int, selection:int) -> int:
	return (mask & ~selector) | selection

static func get_random_point_in_circle(radius:float) -> Vector2:
	# Use polar coordinates for more uniformity than a random direction vector
	var angle := randf() * TAU
	# Must take sqrt as A = PI*r^2 to avoid clumping near center and more area as you approach the surface
	var r := radius * sqrt(randf())
	return Vector2.from_angle(angle).normalized() * r

static func get_random_point_in_sphere(radius:float) -> Vector3:
	# Use spherical coordinates for more uniformity than a random direction vector
	# coordinate system is rotated since Y is up
	# Random horizontal rotation
	var phi := randf() * TAU
	# Corrects the "Pole" crowding         
	var costheta := randf_range(-1, 1)
	
	var theta := acos(costheta)
	# Cube root for volume density
	var r := radius * (randf() ** (1.0/3.0)) 
	
	var sintheta := sin(theta)
	var x := r * sintheta * cos(phi)
	var y := r * cos(theta)
	var z := r * sintheta * sin(phi)
	
	return Vector3(x, y, z)

static func grid_vector(vec:Vector3) -> Vector2:
	return Vector2(vec.x, vec.z)

static func mid_point(range_vec:Vector2) -> float:
	return (range_vec.y - range_vec.x) * 0.5

static func is_between(value: float, range_vec:Vector2) -> bool:
	return value >= range_vec.x and value <= range_vec.y
