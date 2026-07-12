@tool
class_name DialogueHandler
extends Node

signal new_dialogue_step(dialogue_step: DialogueStep)

signal dialogue_progressed
signal dialogue_finished

@export var source: DialogueSource

var current_step: int = -1 # Start at -1 so that we increment to 0 on the first iteration
var _last_loaded_step: int = -1


func get_title() -> String:
	return source.title

func get_current_text() -> String:
	return get_current_step().text

func get_current_speaker() -> String:
	return get_current_step().speaker_name

func get_current_icon() -> Texture2D:
	return get_current_step().icon

func get_current_background() -> Texture2D:
	return get_current_step().background_image

func get_current_alignment() -> int:
	return get_current_step().alignment

func get_current_step() -> DialogueStep:
	return source.get_line_at_index(current_step)


func step_forward() -> void:
	current_step = max(current_step + 1, 0)
	_handle_dialogue_for_step(current_step)

func step_backward() -> void:
	current_step = max(current_step - 1, 0)
	_handle_dialogue_for_step(current_step)

func is_dialogue_complete() -> bool:
	#print("[DialogueHandler] Last step: %s | Step length: %s" % [_last_loaded_step, source.lines.size()])
	return _last_loaded_step == source.lines.size() - 1

func reset() -> void:
	current_step = -1
	_last_loaded_step = 0


func _handle_dialogue_for_step(index: int) -> void:
	if index >= source.lines.size():
		print("[DialogueHandler] Dialogue Finished!")
		dialogue_finished.emit()
		return
	
	if index > _last_loaded_step:
		_last_loaded_step = index

	var current_dialogue := source.get_line_at_index(index)
	new_dialogue_step.emit(current_dialogue)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("[DialogueHandler] Player pressed 'accept'")
		dialogue_progressed.emit()
