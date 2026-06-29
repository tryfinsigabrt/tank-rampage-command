## Audio Manager for managing game sounds and audio concurrency across different sound buses
class_name AudioManager extends Node

@onready var legacy_behavior: AudioManagerLegacy = %LegacyBehavior

## Will be removed after AudioManager pool integration is complete

#region Legacy Behavior
## Plays a one-shot sound that is level-bound so should survive it's current parent node attachment
## Any node can be provided that has a "play" function that takes no arguments
## This could be an AudioStreamPlayer3D or AudioStreamPlayer
func play_level_sound(playable_node:Node) -> void:
	legacy_behavior.play_level_sound(playable_node)
#endregion
