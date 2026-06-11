extends Control

@onready var back_button: Button = %BackButton

func _ready() -> void:
	back_button.grab_focus()

func _on_back_button_pressed() -> void:
	back_button.disabled = true
	await GameManager.scene_manager.main_menu()
