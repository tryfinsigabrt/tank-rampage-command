class_name PositionDistributor extends Node

@export
var enabled:bool = true

@export_range(1.0, 5.0, 0.1)
var min_spacing_angle_deg:float = 4.5

@export_range(1.0, 5.0, 0.1)
var max_spacing_angle_deg:float = 12.0

@export_range(1.0, 360.0, 0.1)
var max_angle_degrees:float = 180.0

@export
var min_unit_separation:float = 4.0

## When > 0, a new concentric ring is created behind to avoid spreading units out too much
@export
var max_group_separation:float = 50.0

var unit_positions:Dictionary[int,Vector3]

var _positions:PackedVector3Array
var _ids:PackedInt64Array
var _distances:PackedFloat32Array

func calculate(units:Array[Unit], desired_position:Vector3) -> Dictionary[int,Vector3]:
	unit_positions.clear()
	
	if not units:
		return unit_positions
		
	var size:int = units.size()

	if not enabled or size == 1:
		for unit in units:
			unit_positions[unit.get_instance_id()] = desired_position
		return unit_positions
	
	_positions.resize(size)
	_ids.resize(size)
	_distances.resize(size)
	
	var avg_dir:Vector3 = Vector3.ZERO
	
	var group_spacing:float = 0.0
	
	for i in size:
		var unit := units[i]
		
		_ids[i] = unit.get_instance_id()
		var pos:Vector3 = unit.global_position
		avg_dir += desired_position - pos
		
		var bounds:AABB = unit.get_bounds()
		# Only care about x component
		var bounds_size := bounds.size
		var dist := bounds_size.x
		group_spacing = maxf(group_spacing, bounds_size.z)
		
		_distances[i] = maxf(dist * 2, min_unit_separation)

	# Go in a semi-circle up to 180 degrees
	# Need to calculate the radius based on the bounding box sizes
	var avg_sep:float = 0.0
	for dist in _distances:
		avg_sep += dist
	avg_sep /= size
	group_spacing *= 2.0
	
	avg_dir = avg_dir.normalized()
	if avg_dir.is_zero_approx():
		avg_dir = Vector3.FORWARD
	
	# Perpendicular chord of circle bisector - half chord length and half angle forms right triangle
	# sin(theta/2) = d / (2*r)
	# r = 0.5 * d / sin(0.5*th)
	var angle_spread:float = deg_to_rad(clampf(0.5 * max_angle_degrees / size, min_spacing_angle_deg, max_spacing_angle_deg))
	#var angle_spread:float =  deg_to_rad(min_spacing_angle_deg)
	var radius:float = 0.5 * avg_sep / sin(0.5 * angle_spread)
	
	# Place positions on the circle using polar coordinates
	# Positions are going to be relative to the center of circle
	var center:Vector3 = desired_position + avg_dir * radius
	var dir_xz:Vector2 = Vector2(avg_dir.x, avg_dir.z)
	
	# Starting angle based on dir reversed
	var max_delta_angle:float = deg_to_rad(max_angle_degrees * 0.5)
	
	# Theta / 2 = sin^-1(0.5*d / r) => [-1,1] => d < 2 * r
	# We want theta/2 as we are moving in increments both above and below the central radial line
	var half_max_separation := max_group_separation * 0.5
	if max_group_separation > 0 and half_max_separation < radius:
		max_delta_angle = asin(half_max_separation / radius)
	
	var starting_angle:float = (-dir_xz).angle()
	var radial_count:int = 0
	var delta_angle:float = 0.0

	for i in size:
		# x = r*cos(theta), y=r*sin(theta)
		var pos:Vector2 = Vector2.from_angle(delta_angle + starting_angle) * radius
		var global_pos := center + Vector3(pos.x, desired_position.y, pos.y)
		_positions[i] = global_pos
		
		# Alternate around circle
		# Technically we should recalculate the next arc from adjacent unit bounds (bounds(neighbor) * 0.5 + bounds(me))
		# But this is already an approx so avoid the calculating dtheta = 2 * sin^-1(0.5*d / r)
		if delta_angle > 0.0:
			delta_angle = -delta_angle
		elif delta_angle <= 0.0:
			delta_angle = -delta_angle + angle_spread
		
		if delta_angle > max_delta_angle:
			radial_count += 1
			delta_angle = 0.0
			
			# Move next line back along radial direction behind the previous
			center -= avg_dir * group_spacing
			# Offset next starting angle slightly
			var offset:float = angle_spread * 0.5
			if radial_count % 2 != 0:
				offset *= -1.0
				
			starting_angle += offset
			
	for i in size:
		unit_positions[_ids[i]] = _positions[i]
	
	return unit_positions
	
