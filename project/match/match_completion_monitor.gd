extends Node

@export
var match_completion_ui_trigger_delay:float = 4.0

@export
var ui_display_root:Node

const MATCH_COMPLETE_SCENE:PackedScene = preload("uid://fig34p3igsvy")

func _ready() -> void:
	SignalBus.match_ended.connect(_on_match_complete)
	
func _on_match_complete(_match_object:Match) -> void:
	if match_completion_ui_trigger_delay > 0:
		await get_tree().create_timer(match_completion_ui_trigger_delay).timeout
	
	var match_complete_ui:Node = MATCH_COMPLETE_SCENE.instantiate()
	var container:Node = ui_display_root if ui_display_root else self
	container.add_child(match_complete_ui)
