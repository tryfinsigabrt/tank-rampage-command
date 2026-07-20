extends Node3D

@onready var emitter_starter: EmitterStarter = %EmitterStarter

func _ready() -> void:
	await emitter_starter.run()
	queue_free()
