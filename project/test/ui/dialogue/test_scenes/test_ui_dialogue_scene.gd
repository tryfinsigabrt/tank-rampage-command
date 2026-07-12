@tool
class_name TestUiDialogueScene
extends Control

@export_tool_button("Start Dialogue") var start_button := start_dialogue
@export_tool_button("Prorgress Dialogue") var progress_dialogue_button := attempt_progress_dialogue
@export_tool_button("Next Line") var next_line_button := next_line

@export_category("Dependencies")
@onready var dialogue_handler: DialogueHandler = %DialogueHandler
@onready var dialogue_container: DialogueContainer = %DialogueContainer

func _ready() -> void:
	_ensure_signals()

func start_dialogue() -> void:
	_ensure_signals()
	print("TEST: Starting dialogue from beginning")
	dialogue_handler.reset()
	dialogue_container.reset_dialogue()

func next_line() -> void:
	_ensure_signals()
	print("TEST: Attempting to step to next line")
	if not dialogue_handler.is_dialogue_complete():
		dialogue_handler.step_forward()
		print("TEST: Progressing to next line of dialogue")
		var new_step := dialogue_handler.get_current_step()
		dialogue_container.add_new_line(new_step)
		dialogue_container.set_background_image(new_step.background_image)
	else:
		print("TEST: Nah, we're already done")

func attempt_progress_dialogue() -> void:
	_ensure_signals()
	if is_instance_valid(dialogue_container.last_line_added):
		var last_line_complete := dialogue_container.is_last_line_finished()
		if not last_line_complete:
			print("TEST: Progressed -> Showing all text for current line")
			dialogue_container.show_all_text_for_last_line()
		else:
			print("TEST: Progressed -> Going to next line")
			next_line()
	else:
		print("TEST: No line yet -> Starting first line")
		next_line()

func _on_new_dialogue_step(_dialogue_step: DialogueStep) -> void:
	print("TEST: New dialogue step signal called!")

func _on_dialogue_progressed() -> void:
	print("TEST: New dialogue progressed signal called!")
	attempt_progress_dialogue()

func _on_dialogue_finished() -> void:
	print("TEST: New dialogue finished signal called!")

func _ensure_signals() -> void:
	var test_dialogue_source: DialogueSource = load("uid://5chpds6kp3ot")
	dialogue_handler.source = test_dialogue_source
	if not dialogue_handler.new_dialogue_step.is_connected(_on_new_dialogue_step):
		dialogue_handler.new_dialogue_step.connect(_on_new_dialogue_step)
	if not dialogue_handler.dialogue_progressed.is_connected(_on_dialogue_progressed):
		dialogue_handler.dialogue_progressed.connect(_on_dialogue_progressed)
	if not dialogue_handler.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_handler.dialogue_finished.connect(_on_dialogue_finished)
