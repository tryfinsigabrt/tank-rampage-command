@tool
extends StaticBody3D

@onready var _collision_shape: CollisionShape3D = $Shape
@onready var _debug_view: CSGBox3D = $DebugView

@export
var refresh_rate:float = 1.0

@export
var debug_draw:bool = true:
	set(value):
		debug_draw = value
		if Engine.is_editor_hint() and _debug_view:
			_debug_view.visible = value
			set_process(value)
			
var _time:float = 0.0

@export
var shape:Shape3D:
	set(value):
		shape = value
		if _collision_shape:
			_collision_shape.shape = shape
	
func _ready() -> void:
	_collision_shape.shape = shape
	
	if Engine.is_editor_hint():
		set_process(debug_draw)
	else:
		_debug_view.queue_free()
		_debug_view = null
		set_process(false)
	
func _refresh_visual() -> void:
	if shape:
		_debug_view.size = Collisions.get_aabb_from_shape(shape).size
	
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_time += delta
	if _time < refresh_rate:
		return
	
	_refresh_visual()
	_time = 0.0
	
