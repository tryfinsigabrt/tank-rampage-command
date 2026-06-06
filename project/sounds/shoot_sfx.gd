## Plays the shoot sound, delegating to the appropriate AudioStreamPlayer
## The weapon only expect a single function with a "play" method
extends Node3D

# TODO: Replace with a pooled audio manager
@onready var shoot_sfx: AudioStreamPlayer3D = $ShootSfx

func play() -> void:
	shoot_sfx.play()
