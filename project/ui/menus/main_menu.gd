extends Control

@onready var main_menu_buttons: VBoxContainer = %MainMenuButtons

@onready var quit: Button = %Quit

func _ready() -> void:
	# Remove buttons that don't function on Web
	if OS.get_name() == "Web":
		quit.hide()
		

func _on_play_pressed() -> void:
	_disable_buttons()
	await GameManager.scene_manager.new_game()

func _on_quit_pressed() -> void:
	_disable_buttons()
	GameManager.scene_manager.quit()

func _disable_buttons() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(main_menu_buttons, 20.0)
