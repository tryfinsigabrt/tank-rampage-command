## Node that gets added to the scene that turns off manufacturing and hides the existing visual root 
## until building is complete
class_name ConstructionBuilding extends Node3D

@export
var resource:ConstructionResource

@export
var material:Material

@export
var mesh_instance:MeshInstance3D

@onready var build_timer: Timer = $BuildTimer
@onready var progress_bar_timer: Timer = $ProgressBarTimer
@onready var progress_bar: BuildProgressBar = $BuildProgressBar

var _building:Building

# FOW vision increases slowly as the asset builds
var _final_vision:float
var _start_vision:float

const BUILD_PROGRESS_BAR:PackedScene = preload("uid://vcmg5a8ggm00")

func _ready() -> void:
	_building = get_parent() as Building
	if not _building:
		push_error("%s: Must be added to a Building parent" % name)
		queue_free()
		return
		
	assert(resource, "resource not set!")
	if not resource:
		queue_free()
		return
	
	# If there is no build time then just queue free and parent will behave fully built
	if resource.time <= 0.0:
		print_debug("%s: No construction time - %s is ready immediately" % [name, _building.name])
		queue_free()
		return
	
	if _building.is_node_ready():
		_start_building()
	else:
		_building.ready.connect(_start_building, CONNECT_ONE_SHOT)

func _exit_tree() -> void:
	if is_instance_valid(progress_bar):
		progress_bar.queue_free()
		progress_bar = null
	if is_instance_valid(mesh_instance):
		mesh_instance.queue_free()
		mesh_instance = null
		
func _start_building() -> void:
	print_debug("%s: Begin construction of %s - %.1fs" % [name, _building.name, resource.time])
	
	var aabb:AABB = _building.get_bounds()
	# Circumscribed radius
	_final_vision = _building.team_component.vision
	_start_vision = minf(MathUtils.grid_vector(aabb.size).length(), _final_vision)

	_building.team_component.vision = _start_vision
	
	for child in _building.visual_root.get_children():
		child.visible = false
		
	_building.manufacturing_component.active = false
	
	progress_bar.get_parent().remove_child(progress_bar)
	
	var new_parent:Node3D = _building.ui_root
	new_parent.add_child(progress_bar)
	
	# Set position so above the ground relative to the _building
	# Done with the local offset in the scene
	#var desired_position:Vector3 = new_parent.to_global(Vector3(0, -1, 0))
	#progress_bar.global_position = desired_position
	
	_create_visuals()
	_start_timers()
	
func _start_timers() -> void:
	build_timer.wait_time = resource.time
	build_timer.start()
	progress_bar_timer.start()
	
func _create_visuals() -> void:
	if not mesh_instance:
		_create_placeholder_visuals()
		
	var existing_parent := mesh_instance.get_parent()
	if existing_parent:
		existing_parent.remove_child(mesh_instance)
		
	_building.visual_root.add_child(mesh_instance)

func _create_placeholder_visuals() -> void:
	# Create based on the collision shape
	var collision:CollisionShape3D = Collisions.get_collisions_nodes(_building).front()
	var collision_shape:Shape3D
	if collision:
		collision_shape = collision.shape
	else:
		push_error("%s: No collision found on building=%s - defaulting to a 5m cube" % [name, _building.name])
		collision_shape = BoxShape3D.new()
		collision_shape.size = Vector3(5.0, 5.0, 5.0)
		
	
	mesh_instance = MeshInstance3D.new()
	
	var mesh:Mesh
	if collision_shape is SphereShape3D:
		mesh = SphereMesh.new()
		mesh.radius = collision_shape.radius
		mesh.is_hemisphere = true
		mesh.radial_segments = 32
		mesh.height = mesh.radius
	else:
		var aabb:AABB = Collisions.get_aabb_from_shape(collision_shape)
		if not aabb.has_volume():
			push_warning("%s: Unsupported collision shape or no volume shape found: %s - using defaults" % [name, collision_shape])
			collision_shape = _create_default_shape()
			aabb = Collisions.get_aabb_from_shape(collision_shape)
		mesh = BoxMesh.new()
		mesh.size = aabb.size
	mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh

static func _create_default_shape() -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 5.0, 5.0)
	return shape
	
func _building_complete() -> void:
	for child in _building.visual_root.get_children():
		child.visible = true
		
	_building.team_component.vision = _final_vision
	_building.manufacturing_component.active = true
	queue_free()

func _update_progress() -> void:
	var progress:float = 1.0 - build_timer.time_left / build_timer.wait_time
	progress_bar.set_progress(progress)
	
	# Slowly increase the vision to full amount as it builds
	_building.team_component.vision = lerpf(_start_vision, _final_vision, progress)
