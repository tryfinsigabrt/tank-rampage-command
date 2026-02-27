class_name FogOfWar extends Node

@export
var visibility_tick_rate:float = 0.2

## Ground or Terrain3D instance
@export
var terrain:Node3D

@export
var use_post_process_overlay:bool = true

@export
var use_terrain_overlay:bool = false

@onready var visible_area_viewport: SubViewport = $VisibleArea
@onready var visible_multi_mesh_instance: FogOfWarVisibilityInstance = $VisibleArea/MultiMeshInstance2D

@onready var explored_area_viewport: SubViewport = $ExploredArea
@onready var explored_area_rect: ColorRect = $ExploredArea/ColorRect
@onready var post_process_quad: MeshInstance3D = $FoWPostProcess


var _player_team:int

var _registered_dissolver_nodes: Dictionary[int, Node3D] = {}
var _cached_nodes: Array[Node3D]
var _nodes_dirty:bool
var _accum_delta:float

func _enter_tree() -> void:
	SignalBus.on_unit_added.connect(_on_unit_added)
	SignalBus.on_unit_killed.connect(_on_unit_killed)
	
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
	_player_team = _get_player_team()
	
	# Recommended await per the get_texture() function documentation when used in _ready
	await RenderingServer.frame_post_draw
		
	var explored_area_material: ShaderMaterial = explored_area_rect.material as ShaderMaterial
	if not explored_area_material:
		push_error("%s: ExploredArea subviewport color rect does not have a shader material!" % name)
		return

	var visible_area_tex := visible_area_viewport.get_texture()
	explored_area_material.set_shader_parameter(&"visible_data_texture", visible_area_tex)
	
	var fow_texture := explored_area_viewport.get_texture()
	if use_post_process_overlay:
		_init_post_process_shader(fow_texture)
	if use_terrain_overlay:
		_init_terrain_shader(fow_texture)

func _init_post_process_shader(fow_texture: ViewportTexture) -> void:
	if not post_process_quad:
		push_warning("%s: FoWPostProcess node missing - no post-process fow applied" % name)
		return

	var post_process_material:ShaderMaterial = post_process_quad.material_override as ShaderMaterial
	if not post_process_material:
		push_warning("%s: FoWPostProcess does not have a shader material override" % name)
		return

	post_process_material.set_shader_parameter(&"fow_viewport_texture", fow_texture)

func _init_terrain_shader(fow_texture: ViewportTexture) -> void:
	if not terrain:
		push_warning("%s: No terrain set - no fow applied to ground" % name)
		return
	
	var visual_instance:GeometryInstance3D = terrain as GeometryInstance3D
	if visual_instance:
		var terrain_material:ShaderMaterial = visual_instance.material_overlay
		if terrain_material:
			terrain_material.set_shader_parameter(&"fow_viewport_texture", fow_texture)
		else:
			push_warning("%s: Terrain node %s does not have a material overlay set" % [name, visual_instance.name])
	# TODO: handle type that is Terrain3D
	else:
		push_warning("%s: Unsupported terrain node %s " % [name, terrain.name])
		
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
	_registered_dissolver_nodes[unit.get_instance_id()] = unit
	_nodes_dirty = true

func _on_unit_killed(unit:Unit) -> void:
	_registered_dissolver_nodes.erase(unit.get_instance_id())
	_nodes_dirty = true
