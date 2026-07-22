extends VFlowContainer

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return	

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_hud"):
		visible = not visible
