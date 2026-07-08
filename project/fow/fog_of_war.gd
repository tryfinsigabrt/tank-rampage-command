class_name FogOfWar extends Node

@warning_ignore("unused_signal")
signal fow_visibility_updated

@export
var visibility_tick_rate:float = 0.19

## Enable/Disable temporarily for testing purposes
@export
var enable:bool = true

## Enable/Disable to allow calculations but remove the overlay for testing purposes
@export
var visible:bool = true

@export_range(0.0, 1.0, 0.01)
var explored_area_modulation:float = 0.3

## Cell size in world units of the explored-area grid for querying the FOW_EXPLORED_CHANNEL without reading the GPU texture
@export_range(0.5, 32.0, 0.5)
var explored_grid_cell_size:float = 4.0

@export_range(0.0, 1.0, 0.01)
var edge_tolerance_scale:float = 1.0

@onready var visible_area_viewport: SubViewport = $VisibleArea
@onready var visible_multi_mesh_instance: FogOfWarVisibilityInstance = $VisibleArea/MultiMeshInstance2D

@onready var explored_area_viewport: SubViewport = $ExploredArea
@onready var explored_area_rect: ColorRect = $ExploredArea/ColorRect
@onready var post_process_quad: MeshInstance3D = $FowPostProcess

@onready var node_visibility_manager: NodeVisibilityManager = $NodeVisibilityManager

const FOW_VISIBLE_CHANNEL:int = 0
const FOW_EXPLORED_CHANNEL:int = 1

var _player_team:int = -1

var _registered_dissolver_nodes: Dictionary[int, Node3D] = {}
var _cached_nodes: Array[Node3D]
var _nodes_dirty:bool
var _accum_delta:float

var _explored_area_material:ShaderMaterial

var _world_aabb:AABB
var _projected_size:Vector2

# CPU-side replica of the visible/explored shader computation. Gameplay visibility
# queries read this instead of the viewport texture — ViewportTexture.get_image
# stalls the pipeline reading the data back from the GPU (~28ms per call)
var _visibility_model:FowVisibilityModel = FowVisibilityModel.new()

# World-unit expansion of each vision square approximating the shader's box
# blur + visible-channel threshold at the edges
var _visibility_edge_tolerance:float

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
		
	SignalBus.on_team_asset_added.connect(_on_asset_added)
	SignalBus.on_team_asset_destroyed.connect(_on_asset_destroyed.unbind(1))
	SignalBus.on_team_asset_changed_teams.connect(_on_asset_changed_teams)
	
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
	# Keep the CPU visibility model in sync with what the multimesh renders
	_visibility_model.update(_cached_nodes, _visibility_edge_tolerance)
	_accum_delta = 0.
	
func _ready() -> void:
	if not enable:
		node_visibility_manager.enable = false
		post_process_quad.visible = false
		return
		
	post_process_quad.visible = visible
	
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

	_visibility_model.configure(_world_aabb, explored_grid_cell_size)

	_explored_area_material = explored_area_rect.material as ShaderMaterial
	if not _explored_area_material:
		push_error("%s: ExploredArea subviewport color rect does not have a shader material!" % name)
		return

	_visibility_edge_tolerance = _compute_visibility_edge_tolerance()

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

func is_node_visible(node: Node3D, visible_threshold:float = node_visibility_manager.visible_channel_threshold, channel:int = FOW_VISIBLE_CHANNEL, require_all:bool = false) -> bool:
	return node_visibility_manager.is_node_visible(node, PackedVector3Array(), visible_threshold, channel, require_all)
	
static func fow_channel_to_mask(fow_channel:int) -> int:
	return 1 << fow_channel
	
## Answers the same visible/explored question as the explored_area_viewport
## texture but from the CPU visibility model - never reads the GPU texture back
func get_fow_value(pos:Vector3, channel_mask:int = 3) -> Vector2:
	var fow_value:Vector2
	var is_visible:bool = false
	
	# Visible
	if (channel_mask & 1) and _visibility_model.is_position_visible(pos):
		fow_value[0] = 1.0
		is_visible = true
	
	# Explored 
	if (channel_mask & 2) and (is_visible or _visibility_model.is_position_explored(pos)):
		fow_value[1] = 1.0
	
	return fow_value

## The shader box-blurs the visible quads (blur_amount texels) before the
## visible-channel threshold is applied, which softens/expands the square
## edges - approximate that by expanding each vision square by the blur
## footprint in world units
func _compute_visibility_edge_tolerance() -> float:
	if is_zero_approx(edge_tolerance_scale):
		return 0.0
		
	var blur_amount:float = 1.5
	if _explored_area_material:
		var blur_param:Variant = _explored_area_material.get_shader_parameter(&"blur_amount")
		if blur_param != null:
			blur_amount = blur_param

	var texel_world_size:Vector2 = map_size / _projected_size
	return blur_amount * maxf(texel_world_size.x, texel_world_size.y) * edge_tolerance_scale

func _clear_explored() -> void:
	explored_area_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_visibility_model.clear_explored()

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
		
func _on_asset_added(asset:Node3D) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component or not team_component.is_on_team(_player_team):
		return
		
	_add_dissolver(asset)

func _add_dissolver(asset:Node3D) -> void:
	_registered_dissolver_nodes[asset.get_instance_id()] = asset
	_nodes_dirty = true
	
func _on_asset_destroyed(asset:Node3D) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component or not team_component.is_on_team(_player_team):
		return
		
	_remove_dissolver(asset)

func _remove_dissolver(asset:Node3D) -> void:
	_registered_dissolver_nodes.erase(asset.get_instance_id())
	_nodes_dirty = true
	
func _on_asset_changed_teams(asset:Node3D, prev_team:int, new_team:int) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component:
		return
		
	if prev_team == _player_team:
		_remove_dissolver(asset)
	elif new_team == _player_team:
		_add_dissolver(asset)
