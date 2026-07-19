class_name DialogueScene
extends Control

@export var dialogue_handler: DialogueHandler
@export var dialogue_container: DialogueContainer


func start_dialogue() -> void:
	print("[DialogueScene] Starting dialogue from beginning")
	dialogue_handler.reset()
	dialogue_container.reset_dialogue()
	var title_text := dialogue_handler.get_title()
	dialogue_container.set_title(title_text)

func next_line() -> void:
	print("[DialogueScene] Attempting to step to next line")
	if not dialogue_handler.is_dialogue_complete():
		dialogue_handler.step_forward()
		print("[DialogueScene] Progressing to next line of dialogue")
		var new_step := dialogue_handler.get_current_step()
		dialogue_container.add_new_line(new_step)
		dialogue_container.set_background_image(new_step.background_image)
	else:
		await _handle_dialogue_complete()

func attempt_progress_dialogue() -> void:
	if is_instance_valid(dialogue_container.last_line_added):
		var last_line_complete := dialogue_container.is_last_line_finished()
		if not last_line_complete:
			print("[DialogueScene] Progressed -> Showing all text for current line")
			dialogue_container.show_all_text_for_last_line()
		else:
			print("[DialogueScene] Progressed -> Going to next line")
			await next_line()
	else:
		print("[DialogueScene] No line yet -> Starting first line")
		await next_line()

func _handle_dialogue_complete() -> void:
	print("[DialogueScene] Dialogue complete - switching to scene...")
	await dialogue_handler.switch_to_target_scene()


func _on_new_dialogue_step(_dialogue_step: DialogueStep) -> void:
	print("[DialogueScene] New dialogue step signal called!")

func _on_dialogue_progressed() -> void:
	print("[DialogueScene] New dialogue progressed signal called!")
	await attempt_progress_dialogue()

func _on_dialogue_finished() -> void:
	print("[DialogueScene] New dialogue finished signal called!")

func _on_dialogue_skipped() -> void:
	print("[DialogueScene] Dialogue has been skipped!")
	await _handle_dialogue_complete()


func _ensure_signals() -> void:
	if not dialogue_handler.new_dialogue_step.is_connected(_on_new_dialogue_step):
		dialogue_handler.new_dialogue_step.connect(_on_new_dialogue_step)
	if not dialogue_handler.dialogue_progressed.is_connected(_on_dialogue_progressed):
		dialogue_handler.dialogue_progressed.connect(_on_dialogue_progressed)
	if not dialogue_handler.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_handler.dialogue_finished.connect(_on_dialogue_finished)
	if not dialogue_container.skip_dialogue.skip_dialogue_triggered.is_connected(_on_dialogue_skipped):
		dialogue_container.skip_dialogue.skip_dialogue_triggered.connect(_on_dialogue_skipped)


func _ready() -> void:
	_ensure_signals()
	start_dialogue()
	next_line.call_deferred()
