extends Control

@onready var content_container: VBoxContainer = %ContentContainer
@onready var pause_menu_panel: Control = %PauseMenuPanel
@onready var options_menu: PanelContainer = %OptionsMenu
@onready var controls_menu: Control = %ControlsReferenceMenu
@onready var resume: Button = %ResumeButton
@onready var quit: Button = %ExitButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton

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

func _on_options_pressed() -> void:
	pause_menu_panel.hide()
	controls_menu.hide()
	options_menu.show()

func _on_controls_pressed() -> void:
	pause_menu_panel.hide()
	options_menu.hide()
	controls_menu.show()

func _update_visibility(paused:bool) -> void:
	if paused:
		options_menu.hide()
		controls_menu.hide()
		pause_menu_panel.show()
		show()
	else:
		hide()
		
func _on_quit_pressed() -> void:
	_disable_buttons()
	GameManager.scene_manager.quit()

func _disable_buttons() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(content_container, 20.0)

func _on_options_menu_back_requested() -> void:
	options_menu.hide()
	pause_menu_panel.show()

func _on_controls_menu_back_requested() -> void:
	controls_menu.hide()
	pause_menu_panel.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.scene_manager.toggle_pause()


func _on_quit_to_menu_button_pressed() -> void:
	_disable_buttons()
	
	await GameManager.scene_manager.main_menu()
