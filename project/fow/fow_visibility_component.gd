class_name FOWVisibilityComponent extends Node

signal on_visibility_changed(node:Node3D, in_visible:bool)

@export
var root:Node3D

var _fow:FogOfWar

func _ready() -> void:
	if not GameManager.fog_of_war:
		queue_free()
		return
	
	_fow = GameManager.fog_of_war_node
	assert(_fow)
	_fow.fow_visibility_updated.connect(_on_fow_visibility_updated)

	if not root:
		var scene_root:Node = Groups.get_scene_root(self)
		if scene_root is Node3D:
			root = scene_root
		else:
			root = Groups.get_child_with_type(scene_root, Node3D)
		if not root:
			assert("%s: Not added to a scene that has a Node3D!" % name)
			queue_free()
			return
			
	# Initially not visible
	on_visibility_changed.emit(root, false)
		
func _on_fow_visibility_updated() -> void:
	var is_visible:bool = _fow.is_node_visible(root)
	on_visibility_changed.emit(root, is_visible)
	
