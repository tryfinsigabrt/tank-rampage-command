class_name NodePicker extends Node3D

@export
var ray_cast_distance:float = 10000

@export
var project_ground_max_dist:float = 100.0

@export
var box_select_min_height:float = 20.0

@export
var camera:Camera3D

var is_valid:bool:
	get: return is_instance_valid(camera)

func _ready() -> void:
	if not camera:
		_pick_camera.call_deferred()

func project_to_ground(in_position:Vector3) -> Vector3:
	var from:Vector3 = in_position + Vector3.UP * 1000.0
	var to:Vector3 = in_position + Vector3.DOWN * project_ground_max_dist
	
	var result: Dictionary = _ray_cast(from, to, Collisions.CompositeMasks.ground)
	if not result:
		push_warning("%s: Could not find ground for position:%s" % [name, in_position])
		return Vector3.INF
	
	var ground:Vector3 = result["position"]
	return Vector3(in_position.x, ground.y, in_position.z)

func pick_ground(event: InputEvent) -> Dictionary:
	return pick_node(event, Collisions.CompositeMasks.ground)
	
func pick_unit_screen_area(screen_area:Rect2) -> Array[Unit]:
	if screen_area.has_area():
		return [] as Array[Unit]
		
	var collision_mask:int = Collisions.CompositeMasks.ground
	var result := pick_position(screen_area.position, collision_mask)
	if not result:
		return [] as Array[Unit]
	
	var bounds:AABB
	bounds.position = result["position"]
	
	result = pick_position(screen_area.end, collision_mask)
	if not result:
		return [] as Array[Unit]
	
	bounds.end = result["position"]
		
	return pick_unit_world_bounds(bounds)

func pick_unit_world_bounds(bounds: AABB) -> Array[Unit]:
	var units:Array[Unit]
		
	# Sometimes the size is negative and so need to take abs
	bounds = bounds.abs()
	
	var size:Vector3 = bounds.size
	if size.y < box_select_min_height:
		size.y = box_select_min_height
		bounds.size = size
				
	if not bounds.has_volume():
		return units
	
	var space_state := get_world_3d().direct_space_state
	
	var params := PhysicsShapeQueryParameters3D.new()
	var shape_rid:RID = PhysicsServer3D.box_shape_create()
	
	# Box Shape expects Vector3 containing half extents of the box
	PhysicsServer3D.shape_set_data(shape_rid, bounds.size * 0.5 )
	
	params.shape_rid = shape_rid
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = Collisions.Layers.unit
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	
	var results: Array[Dictionary] = space_state.intersect_shape(params)
	PhysicsServer3D.free_rid(shape_rid)

	for result in results:
		var unit:Unit = result.get("collider") as Unit
		if unit and not unit in units:
			units.push_back(unit)
			
	return units
		
func pick_unit(event: InputEvent) -> Unit:
	var result := pick_node(event, Collisions.Layers.unit)
	if not result:
		return
	var clicked_object: Node = result.collider
	return Groups.get_parent_in_group(clicked_object, Groups.Unit)

func pick_team_asset(event: InputEvent) -> Node3D:
	var result := pick_node(event, Collisions.CompositeMasks.team_asset)
	if not result:
		return
	var clicked_object: Node = result.collider
	return Groups.get_parent_in_group(clicked_object, Groups.TeamAsset)
	
func pick_node(event: InputEvent, collision_mask:int) -> Dictionary:
	return pick_position(event.position, collision_mask)

func pick_position(screen_position:Vector2, collision_mask:int) -> Dictionary:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * ray_cast_distance  # Long ray

	return _ray_cast(from, to, collision_mask)
	
func _ray_cast(from: Vector3, to: Vector3, collision_mask:int) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = collision_mask
	ray_params.from = from
	ray_params.to = to
	
	return space_state.intersect_ray(ray_params)	
	
func _pick_camera() -> void:
	camera = get_viewport().get_camera_3d()
	print_debug("%s: Defaulting to use current viewport camera: %s" % [name, camera])
