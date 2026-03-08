extends Node3D

@export var scene: PackedScene
@export var quantity: int = 100

@export var spacing: Vector2i = Vector2i(1, 1)
@export var row_length: int = 25

@onready var instances: Node3D = $Instances
@onready var debug_label: Label3D = $Camera3D/DebugLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not scene:
		push_error("No scene configured! Quitting...")
		get_tree().quit()
	else:
		## Unlock the framerate for testing
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		
		stress()
		

func stress():
	var row: int = 0
	for i in quantity:
		var new_instance = scene.instantiate()
		instances.add_child(new_instance)
		
		new_instance.global_position = Vector3(
			(i - (row * row_length)) * spacing.x,
			0.0, row * spacing.y
			)
		row = i / row_length
		#print(i * spacing.x, row)
	
	debug_label.text = "%d instances" % quantity

func _process(delta: float) -> void:
	debug_label.text = "%d instances\n%s fps" % [quantity, Engine.get_frames_per_second()]
