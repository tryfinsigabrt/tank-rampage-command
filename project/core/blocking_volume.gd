@tool
extends StaticBody3D

@onready var _collision_shape: CollisionShape3D = $Shape
@onready var _debug_view: CSGBox3D = $DebugView
@onready var _dynamic_nav_obstacle: DynamicNavObstacle = $DynamicNavObstacle

@export
var refresh_rate:float = 1.0

@export
var debug_draw:bool = true:
	set(value):
		debug_draw = value
		if Engine.is_editor_hint() and _debug_view:
			_debug_view.visible = value
			set_process(value)

## Show the debug shape in gameplay
## Used for testing
@export
var gameplay_draw:bool
			
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
		_update_nav_obstacle()

		if not gameplay_draw:
			_debug_view.queue_free()
			_debug_view = null
		else:
			_refresh_visual()
			
		set_process(false)
	
func _refresh_visual() -> void:
	if shape:
		_debug_view.size = Collisions.get_aabb_from_shape(shape).size

func _update_nav_obstacle() -> void:
	var unit_classes:Array[Unit.UnitClass]
	var default_avoidance_layers:int = 0
	
	if collision_layer & Collisions.Layers.world_static:
		default_avoidance_layers = Avoidance.LAYER_ALL
	else:
		if collision_layer & (Collisions.Layers.unit | Collisions.Layers.vehicle):
			unit_classes.push_back(Unit.UnitClass.Artillery)
			unit_classes.push_back(Unit.UnitClass.Tank)
		if collision_layer & (Collisions.Layers.unit | Collisions.Layers.infantry):
			unit_classes.push_back(Unit.UnitClass.Soldier)
			
	_dynamic_nav_obstacle.affects_unit_classes = unit_classes
	_dynamic_nav_obstacle.default_avoidance_layers = default_avoidance_layers
	_dynamic_nav_obstacle.refresh_avoidance_layers()
	
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_time += delta
	if _time < refresh_rate:
		return
	
	_refresh_visual()
	_time = 0.0
	
