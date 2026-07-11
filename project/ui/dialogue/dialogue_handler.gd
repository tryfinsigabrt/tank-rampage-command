@tool
class_name DialogueHandler
extends Node

signal background_image_changed(new_bg_image: Texture2D)
signal speaker_icon_changed(new_speaker_icon: Texture2D)
signal new_text_line(new_text: String)
signal dialogue_finished

@export var text_resource: JSON

var current_step: int = -1 # Start at -1 so that we increment to 0 on the first iteration
var _last_loaded_step: int = 0


func get_title() -> String:
	return text_resource.title

func get_current_text() -> String:
	return _get_data().lines[current_step].text

func get_current_icon() -> Texture2D:
	return load(_get_data().lines[current_step].icon)

func get_current_background() -> Texture2D:
	return load(_get_data().lines[current_step].background)

func get_current_alignment() -> int:
	return _get_data().lines[current_step].alignment


func step_forward() -> void:
	current_step = max(current_step + 1, 0)
	_handle_dialogue_for_step(current_step)

func step_backward() -> void:
	current_step = max(current_step - 1, 0)
	_handle_dialogue_for_step(current_step)

func reset() -> void:
	current_step = -1
	_last_loaded_step = 0

func _handle_dialogue_for_step(index: int) -> void:
	if index >= _get_data().lines.size():
		print("[DialogueHandler] Dialogue Finished!")
		dialogue_finished.emit()
		return

	var current_dialogue := _parse_step(index)
	if current_dialogue.has("background"):
		var background_texture := load(current_dialogue.background)
		background_image_changed.emit(background_texture)
	if current_dialogue.has("icon"):
		var icon_texture := load(current_dialogue.icon)
		speaker_icon_changed.emit(icon_texture)
	if current_dialogue.has("text"):
		new_text_line.emit(current_dialogue.text)
	if current_dialogue.has("alignment"):
		new_text_line.emit(current_dialogue.text)


func _parse_step(index: int) -> Dictionary:
	print("[DialogueHandler] Parsing JSON text...")
	var parse_text: Dictionary = _get_data()
	#print("JSON = %s" % [parse_text])
	#print("CurrLine = %s" % [parse_text.lines[index]])
	return parse_text.lines[index]

func _get_data() -> Dictionary:
	return text_resource.data
