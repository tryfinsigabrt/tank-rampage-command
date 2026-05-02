class_name FOWVisibilityToggler extends Node

enum FOWRenderBehavior
{
	EXPLORED,
	VISIBLE
}

@export
var render_behavior:FOWRenderBehavior = FOWRenderBehavior.EXPLORED

var _first_visibility_change:bool = true

func _ready() -> void:
	if not GameManager.fog_of_war:
		queue_free()
		return
		
	var fow_visibility_component: FOWVisibilityComponent = get_parent() as FOWVisibilityComponent
	if not fow_visibility_component:
		assert("%s: Not added as a child of FOWVisibilityComponent" % name)
		queue_free()
		return
	fow_visibility_component.on_visibility_changed.connect(_on_visibility_changed)
		
func _on_visibility_changed(node:Node3D, in_visible:bool) -> void:
	if in_visible or render_behavior == FOWRenderBehavior.VISIBLE or _first_visibility_change:
		var was_visible:bool = node.visible
		node.visible = in_visible
		_first_visibility_change = false
		if was_visible != in_visible:
			SignalBus.on_fow_node_visibility_changed.emit(node, in_visible)
