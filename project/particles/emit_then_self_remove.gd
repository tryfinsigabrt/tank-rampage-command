extends Node
@export var remove_delay: float = 7.0

func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true

	await get_tree().create_timer(remove_delay).timeout
	queue_free()
