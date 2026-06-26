extends Node2D

@export var outline_color: Color = Color(0.4, 1.0, 0.4, 0.95)
@export var outline_width: float = 2.0

@onready var minimap: MiniMap = get_parent() as MiniMap
@onready var minimap_viewport: SubViewport = %MiniMapViewport
@onready var minimap_camera: Camera3D = %MiniMapCamera

var _rts_camera: RTSCamera
var _polygon: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if player:
		_rts_camera = player.camera
	
	if _rts_camera == null:
		push_warning("No RTSCamera found for camera view overlay")
		return

	_rts_camera.ground_view_polygon_changed.connect(_on_ground_view_polygon_changed)


func _exit_tree() -> void:
	if _rts_camera:
		_rts_camera.ground_view_polygon_changed.disconnect(_on_ground_view_polygon_changed)


func _on_ground_view_polygon_changed(ground_polygon: PackedVector3Array) -> void:
	if minimap == null or minimap_viewport == null or minimap_camera == null or ground_polygon.size() != 4:
		_polygon = PackedVector2Array()
		queue_redraw()
		return

	var viewport_size := Vector2(minimap_viewport.size)
	var scale_factor := minimap.size / viewport_size

	var points := PackedVector2Array()
	for world_point in ground_polygon:
		var viewport_point := minimap_camera.unproject_position(world_point)
		points.push_back(viewport_point * scale_factor)

	_polygon = points
	queue_redraw()


func _draw() -> void:
	if _polygon.size() != 4:
		return

	for i in _polygon.size():
		var from := _polygon[i]
		var to := _polygon[(i + 1) % _polygon.size()]
		draw_line(from, to, outline_color, outline_width)
