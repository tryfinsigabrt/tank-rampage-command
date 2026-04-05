extends Node3D

@onready var timer: Timer = $Timer

@export
var repeat_delay:float = 1.0

@export
var initial_delay:float = 1.0

@export
var wait_for_free:bool = true

@export
var vfx_scene:PackedScene

@onready var spawned: Node3D = $Spawned

func _ready() -> void:
	if not vfx_scene:
		push_error("%s: VFX Scene not set!" % name)
		return
	
	if initial_delay > 0:
		await get_tree().create_timer(initial_delay).timeout
	
	if repeat_delay > 0:
		timer.wait_time = repeat_delay
		timer.timeout.connect(_spawn_scene)
		
	_spawn_scene()

func _spawn_scene() -> void:
	var scene: Node = vfx_scene.instantiate()
	if wait_for_free:
		scene.tree_exited.connect(_start_timer)
	else:
		for child in spawned.get_children():
			child.queue_free()
		_start_timer()
		
	spawned.add_child(scene)

func _start_timer() -> void:
	if repeat_delay > 0:
		timer.start()
