## Audio Manager for managing game sounds and audio concurrency across different sound buses
class_name AudioManager extends Node

var _level_audio_container:Node

## Plays a one-shot sound that is level-bound so should survive it's current parent node attachment
## Any node can be provided that has a "play" function that takes no arguments
## This could be an AudioStreamPlayer3D or AudioStreamPlayer
func play_level_sound(playable_node:Node) -> void:
	if not playable_node:
		return
	if not playable_node.has_method("play"):
		push_warning("%s: playable_node=%s does not have a play() function" % [name, playable_node.name])
		return
		
	var level_audio_container:Node = _get_level_audio_container()
	var current_parent:Node = playable_node.get_parent()
	if current_parent != level_audio_container:
		playable_node.reparent(level_audio_container)
		
		# Delete player after original parent leaves tree after sound finishes if playing at time of death
		current_parent.tree_exiting.connect(func() -> void:
			if playable_node is AudioStreamPlayer3D or playable_node is AudioStreamPlayer:
				if playable_node.playing:
					# Queue free once finished
					playable_node.finished.connect(playable_node.queue_free)
					return
			playable_node.queue_free()
		)
	
	playable_node.play()
	
#region Level Audio
func _get_level_audio_container() -> Node:
	if is_instance_valid(_level_audio_container):
		return _level_audio_container
	
	_level_audio_container = null
	
	var level_audio_container:Node = get_tree().get_first_node_in_group(Groups.LevelAudio)
	if level_audio_container:
		_level_audio_container = level_audio_container
		return _level_audio_container
		
	push_warning("%s: No node in tree tagged with 'LevelAudio' - using slow path finding first Node3D in scene" % name)
	# Find first Node3D in the tree
	var level_root:Node = _get_level_root()
	var first_node_3d:Node3D = Groups.get_child_with_type(level_root, Node3D)
	if first_node_3d:
		_level_audio_container = first_node_3d
	else:
		push_warning("%s: Could not find any Node3D in tree rooted at %s" % [name, level_root.name])
		_level_audio_container = level_root
		
	return _level_audio_container

func _get_level_root() -> Node:
	var tree := get_tree()
	var node:Node = tree.current_scene
	if node:
		print_debug("%s: Using node %s as the level root" % [name, node.name])
		return node
	var root:Window = tree.root
	var child_count:int = root.get_child_count()
	if not child_count:
		push_warning("%s: Root node does not have any children!  Using root %s as the level root" % [name, root.name])
		return root
		
	node = root.get_child(-1)
	print_debug("%s: Using last root child node %s as the level root" % [name, node.name])
	return node
#endregion
