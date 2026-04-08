class_name CameraCentering extends Node3D

@export
var ideal_distance_from_closest_focus:float = 100.0

@export
var zoom_v_bounds_area:Curve

var camera:RTSCamera
var player_team:MatchTeam

func initialize() -> void:
	if not camera or not player_team:
		push_error("%s: camera or player team not set" % name)
		return
	if not zoom_v_bounds_area:
		push_warning("%s: No zoom curve set - camera zoom adjustment disabled" % name)
		
	SignalBus.match_ready.connect(_on_match_ready.unbind(1), ConnectFlags.CONNECT_ONE_SHOT)

func _on_match_ready() -> void:
	recenter()

func recenter() -> void:
	# Get all our units and then determine the average orientation
	var units:Array[Unit] = player_team.units
	if not units:
		print_debug("%s: No units - skipping recentering" % name)
		return
	
	var avg_orientation:Vector3 = Vector3.ZERO
	for unit in units:
		avg_orientation += unit.global_forward
	
	avg_orientation /= units.size()
	avg_orientation = avg_orientation.normalized()
	
	var bounds:AABB
	for unit in units:
		bounds = bounds.expand(unit.global_position)
	
	if not bounds.has_volume():
		var current_size:Vector3 = bounds.size
		bounds.size = Vector3(maxf(current_size.x, 0.01), maxf(current_size.y, 0.01), maxf(current_size.z, 0.01))
	# Find initial camera reference point
	var center:Vector3 = bounds.get_center()
	var ray_start:Vector3 = center - avg_orientation * 100000
	
	var result:Variant = bounds.intersects_ray(ray_start, avg_orientation)
	var camera_reference_start:Vector3 
	
	if not result:
		push_warning("%s: Could not find camera start reference - using bounds center with offset")
		camera_reference_start = center
	else:
		camera_reference_start = result as Vector3
	
	var camera_position:Vector3 = camera_reference_start - avg_orientation * ideal_distance_from_closest_focus
	print_debug("%s: Focusing camera on %s" % [name, camera_position])
	
	camera.move_to(camera_position)
	# Align rotation along the avg_orientation
	var forward:Vector3 = -avg_orientation
	var right := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	camera.transform.basis = Basis(right, up, forward)
	
	if zoom_v_bounds_area:
		#Set initial zoom based on area of bounds fitted to a curve
		var ground_area:float = bounds.get_volume() / bounds.get_shortest_axis_size()
		#print_debug("%s: Bounding area=%f" % [name, ground_area])
	
		var zoom:float = zoom_v_bounds_area.sample_baked(ground_area)
		print_debug("%s: Adjusting camera zoom from %f -> %f" % [name, camera.zoom, zoom])
		camera.zoom = zoom
		
