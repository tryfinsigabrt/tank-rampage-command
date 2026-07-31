extends Node

const ANIMATION_LIBRARY_ANIM_NAME: String = "ANIMS"

@export
var animation_root_scene:PackedScene

@export
var animation_libary:AnimationLibrary


## Dictionary of animation key name and the time to wait for it to play
@export
var animation_cycles:Dictionary[StringName, float]

## Removes any offscreen notifier nodes from the scene to be sure the animation plays
@export
var remove_onscreen_notifiers:bool = true


func get_precompilation_wait_time() -> float:
	var wait_time:float = 0.0
	for cycle_key in animation_cycles:
		wait_time += maxf(animation_cycles[cycle_key], 0.0)
		
	return wait_time + 0.1 if animation_cycles else 0.0

func _ready() -> void:
	var scene:Node = animation_root_scene.instantiate()
	add_child(scene)
	
	var animation_player:AnimationPlayer = Groups.get_child_with_type(scene, AnimationPlayer)
	if not animation_player:
		push_warning("%s: animation_root_scene has no animation player!" % name)
		return
	
	if remove_onscreen_notifiers:
		var offscreen_notifiers:Array[Node] = Groups.get_children_with_type(scene, VisibleOnScreenNotifier3D)
		for notifier in offscreen_notifiers:
			notifier.queue_free()
		await get_tree().process_frame
	
	# If there is animation library override, use it
	if animation_libary:
		animation_player.add_animation_library(ANIMATION_LIBRARY_ANIM_NAME, animation_libary)
	
	animation_player.active = true
	
	for animation_key in animation_cycles:
		var wait_time:float = animation_cycles[animation_key]
		var player_key:String = "%s/%s" % [ANIMATION_LIBRARY_ANIM_NAME, animation_key] if animation_libary else str(animation_key)
		
		animation_player.play(player_key)
		if wait_time > 0:
			await get_tree().create_timer(wait_time).timeout
			
