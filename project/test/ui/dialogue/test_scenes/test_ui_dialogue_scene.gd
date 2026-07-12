@tool
class_name TestUiDialogueScene
extends Control

@export_tool_button("Start Dialogue") var start_button := start_dialogue
@export_tool_button("Next Line") var next_line_button := next_line

@export_category("Dependencies")
@onready var dialogue_handler: DialogueHandler = %DialogueHandler
@onready var dialogue_container: DialogueContainer = %DialogueContainer

var _has_finished := false

func start_dialogue() -> void:
	_ensure_signals()
	print("TEST: Starting dialogue from beginning")
	_has_finished = false
	dialogue_handler.reset()
	dialogue_container.reset_dialogue()


func next_line() -> void:
	_ensure_signals()
	print("TEST: Progressing to next line of dialogue")
	dialogue_handler.step_forward()
	if not _has_finished:
		var new_text := dialogue_handler.get_current_text()
		var new_icon := dialogue_handler.get_current_icon()
		var new_alignment := dialogue_handler.get_current_alignment()
		var new_background := dialogue_handler.get_current_background()
		dialogue_container.set_background_image(new_background)
		dialogue_container.add_new_line(new_text, new_icon, new_alignment)
	else:
		print("TEST: Nah, we're already done")


func _on_new_dialogue_step(_dialogue_step: DialogueStep) -> void:
	print("TEST: New dialogue step signal called!")

func _on_dialogue_finished() -> void:
	print("TEST: New dialogue finished signal called!")
	_has_finished = true

func _ensure_signals() -> void:
	var test_dialogue_source: DialogueSource = load("uid://5chpds6kp3ot")
	dialogue_handler.source = test_dialogue_source
	if not dialogue_handler.new_dialogue_step.is_connected(_on_new_dialogue_step):
		dialogue_handler.new_dialogue_step.connect(_on_new_dialogue_step)
	if not dialogue_handler.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_handler.dialogue_finished.connect(_on_dialogue_finished)
