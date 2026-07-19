extends Control

@onready var main_menu_buttons: VBoxContainer = %MainMenuButtons
@onready var main_menu_container: Control = %MainMenuContainer
@onready var options_menu: PanelContainer = %OptionsMenu
@onready var controls_menu: Control = %ControlsReferenceMenu

@onready var quit: Button = %Quit

func _ready() -> void:
	# Remove buttons that don't function on Web
	if OS.get_name() == "Web":
		quit.hide()
		
	options_menu.back_requested.connect(_on_options_menu_back_requested)
	controls_menu.back_requested.connect(_on_controls_menu_back_requested)


func _on_play_pressed() -> void:
	_disable_buttons()
	await GameManager.scene_manager.play_now()


func _on_level_select_pressed() -> void:
	_disable_buttons()
	await GameManager.scene_manager.level_select_menu()


func _on_options_pressed() -> void:
	main_menu_container.hide()
	controls_menu.hide()
	options_menu.show()

func _on_controls_pressed() -> void:
	main_menu_container.hide()
	options_menu.hide()
	controls_menu.show()


func _on_quit_pressed() -> void:
	_disable_buttons()
	GameManager.scene_manager.quit()


func _on_options_menu_back_requested() -> void:
	options_menu.hide()
	main_menu_container.show()

func _on_controls_menu_back_requested() -> void:
	controls_menu.hide()
	main_menu_container.show()


func _disable_buttons() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(main_menu_buttons, 20.0)


func _on_tutorial_pressed() -> void:
	await GameManager.scene_manager.play_tutorial()


func _on_credits_button_pressed() -> void:
	await GameManager.scene_manager.credits()
