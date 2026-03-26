class_name FogOfWar extends Node

@export
var visibility_tick_rate:float = 0.19

## Enable/Disable temporarily for testing purposes
@export
var enable:bool = true

@export_range(0.0, 1.0, 0.01)
var explored_area_modulation:float = 0.3

@onready var visible_area_viewport: SubViewport = $VisibleArea
@onready var visible_multi_mesh_instance: FogOfWarVisibilityInstance = $VisibleArea/MultiMeshInstance2D

@onready var explored_area_viewport: SubViewport = $ExploredArea
@onready var explored_area_rect: ColorRect = $ExploredArea/ColorRect
@onready var post_process_quad: MeshInstance3D = $FowPostProcess

@onready var node_visibility_manager: NodeVisibilityManager = $NodeVisibilityManager

var _player_team:int = -1

var _registered_dissolver_nodes: Dictionary[int, Node3D] = {}
var _cached_nodes: Array[Node3D]
var _nodes_dirty:bool
var _accum_delta:float

var _explored_area_material:ShaderMaterial

var _world_aabb:AABB
var _projected_size:Vector2

var player_team:int:
	get:
		return _player_team
		
var world_to_view_scale:Vector2:
	get:
		return _projected_size / map_size
	
var map_size:Vector2:
	get:
		var world_size:Vector3 = _world_aabb.size
		var size:Vector2 = Vector2(world_size.x, world_size.z)
		return size

## Adjusted position of world such that this position is at 0,0 on the 2D fow map (top-left)
var map_origin:Vector2:
	get:
		var map_bounds_pos:Vector3 = _world_aabb.position
		return Vector2(map_bounds_pos.x, map_bounds_pos.z)
				
func _enter_tree() -> void:
	if not enable:
		process_mode = Node.PROCESS_MODE_DISABLED
		return
		
	SignalBus.on_unit_added.connect(_on_unit_added)
	SignalBus.on_unit_killed.connect(_on_unit_killed.unbind(1))
	
# Use process for smoother tick rate
func _process(delta: float) -> void:
	_accum_delta += delta
	
	if _accum_delta < visibility_tick_rate:
		return
	
	if _nodes_dirty:
		_cached_nodes = _registered_dissolver_nodes.values() as Array[Node3D]
		_nodes_dirty = false
		# Skip this frame
		return
	
	visible_multi_mesh_instance.update(_cached_nodes)
	_accum_delta = 0.0
	
func _ready() -> void:
	if not enable:
		node_visibility_manager.enable = false
		return
		
	_player_team = _get_player_team()
	
	# Recommended await per the get_texture() function documentation when used in _ready
	await RenderingServer.frame_post_draw
	
	var world_boundaries:WorldBoundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries)
	if world_boundaries:
		_world_aabb = world_boundaries.bounds
	else:
		push_warning("%s: No world boundaries in scene - falling back to static 1000x1000x1000 world size" % name)
		_world_aabb = AABB(Vector3.ZERO, Vector3(500.0,500.0,500.0))
	
	_projected_size = explored_area_viewport.size
		
	_explored_area_material = explored_area_rect.material as ShaderMaterial
	if not _explored_area_material:
		push_error("%s: ExploredArea subviewport color rect does not have a shader material!" % name)
		return

	var visible_area_tex := visible_area_viewport.get_texture()
	_explored_area_material.set_shader_parameter(&"visible_data_texture", visible_area_tex)
	
	var fow_texture := explored_area_viewport.get_texture()
	_init_post_process_shader(fow_texture)

	# Prevents a brief "white clear" that permanently sets everything to explored on start
	await _clear_explored()
	
func project_position(pos:Vector3) -> Vector2:
	# Remap coordinates so that pos of 0,0 is top left of the bounding box
	var adjusted_pos:Vector3 = pos - _world_aabb.position
	var projected_size:Vector3 = _world_aabb.size

	# Convert World XZ to a percentage (0.0 to 1.0) i.e. a uv coordinate
	var uv:Vector2 = Vector2(
		adjusted_pos.x / projected_size.x,
		adjusted_pos.z / projected_size.z
	).clampf(0.0, 1.0)

	# Multiply by viewport size to get the pixel coordinate
	var viewport_pos := uv * _projected_size
	
	return viewport_pos

func get_fow_value(pos:Vector3) -> Color:
	# Read the value of the texture on explored_area_viewport converting pos to the image pixel coordinates (inverse of project_position)
	var viewport_pos:Vector2 = project_position(pos)
	
	var fow_texture:ViewportTexture = explored_area_viewport.get_texture()
	if not fow_texture:
		return Color.BLACK

	var image:Image = fow_texture.get_image()
	if not image or image.is_empty():
		return Color.BLACK

	var image_size:Vector2i = image.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return Color.BLACK

	var pixel:Vector2i = Vector2i(viewport_pos.floor())
	pixel.x = clampi(pixel.x, 0, image_size.x - 1)
	pixel.y = clampi(pixel.y, 0, image_size.y - 1)

	return image.get_pixelv(pixel)
	
func _clear_explored() -> void:
	explored_area_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	
	# Also need to clear the explored area memory
	# This didn't work and setting "Transparent BG" on the explored area DID clear it to black
	# but leaving this here in case we do want to clear it through gameplay
	
	_explored_area_material.set_shader_parameter(&"reset", true)
	await get_tree().create_timer(0.1).timeout
	_explored_area_material.set_shader_parameter(&"reset", false)

func _init_post_process_shader(fow_texture: ViewportTexture) -> void:
	if not post_process_quad:
		push_warning("%s: FoWPostProcess node missing - no post-process fow applied" % name)
		return

	var post_process_material:ShaderMaterial = post_process_quad.material_override as ShaderMaterial
	if not post_process_material:
		push_warning("%s: FoWPostProcess does not have a shader material override" % name)
		return

	post_process_material.set_shader_parameter(&"fow_viewport_texture", fow_texture)	
	post_process_material.set_shader_parameter(&"fow_world_pos", map_origin)
	post_process_material.set_shader_parameter(&"fow_world_size", map_size)
	post_process_material.set_shader_parameter(&"explored_visibility", explored_area_modulation)
		
func _get_player_team() -> int:
	var player := get_tree().get_first_node_in_group(Groups.Player)
	if not player:
		push_error("%s: No player group tagged node in scene - FOW will not work correctly!" % name)
		return -1
	var match_team:MatchTeam = Groups.get_parent_in_group(player, Groups.MatchTeam)
	if not match_team:
		push_error("%s: Player node %s does not have a match team parent - FOW will not work correctly!" % [name, player.name])
		return -1
	return match_team.team
		
func _on_unit_added(unit:Unit) -> void:
	if not unit.is_on_team(_player_team):
		return
	_registered_dissolver_nodes[unit.get_instance_id()] = unit
	_nodes_dirty = true

func _on_unit_killed(unit:Unit) -> void:
	if not unit.is_on_team(_player_team):
		return
		
	_registered_dissolver_nodes.erase(unit.get_instance_id())
	_nodes_dirty = true
