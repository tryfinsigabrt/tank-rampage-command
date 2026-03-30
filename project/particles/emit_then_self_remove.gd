extends Node
@onready var particles = $GPUParticles3D
@export var remove_delay: float = 2.0

func _ready():
    particles.emitting = true
    await get_tree().create_timer(remove_delay).timeout
    queue_free()
