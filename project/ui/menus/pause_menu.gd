extends Control

@onready var content_container: VBoxContainer = %ContentContainer
@onready var resume: Button = %ResumeButton
@onready var quit: Button = %QuitButton

func _ready() -> void:
	SignalBus.on_paused.connect(_on_game_pause_state_changed)
	
	# Remove buttons that don't function on Web
	if OS.get_name() == "Web":
		quit.hide()

	_update_visibility(GameManager.scene_manager.paused)

func _on_game_pause_state_changed(paused:bool) -> void:
	_update_visibility(paused)

func _on_resume_pressed() -> void:
	GameManager.scene_manager.pause_game(false)

func _update_visibility(paused:bool) -> void:
	if paused:
		show()
	else:
		hide()
		
func _on_quit_pressed() -> void:
	_disable_buttons()
	GameManager.scene_manager.quit()

func _disable_buttons() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(content_container, 20.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.scene_manager.toggle_pause()
