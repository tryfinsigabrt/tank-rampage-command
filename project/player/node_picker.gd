class_name NodePicker extends Node3D

@export
var ray_cast_distance:float = 10000

@export
var camera:Camera3D

var is_valid:bool:
	get: return is_instance_valid(camera)

func _ready() -> void:
	if not camera:
		_pick_camera.call_deferred()

func pick_ground(event: InputEvent) -> Dictionary:
	return pick_node(event, Collisions.CompositeMasks.ground)
	
func pick_unit(event: InputEvent) -> Unit:
	var result := pick_node(event, Collisions.Layers.unit)
	if not result:
		return
	var clicked_object = result.collider
	return Groups.get_parent_in_group(clicked_object, Groups.Unit)
	
func pick_node(event: InputEvent, collision_mask:int) -> Dictionary:
	var from := camera.project_ray_origin(event.position)
	var to := from + camera.project_ray_normal(event.position) * ray_cast_distance  # Long ray

	var space_state := get_world_3d().direct_space_state
	
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.collision_mask = collision_mask
	ray_params.from = from
	ray_params.to = to
	
	return space_state.intersect_ray(ray_params)

func _pick_camera() -> void:
	camera = get_viewport().get_camera_3d()
	print_debug("%s: Defaulting to use current viewport camera: %s" % [name, camera])
