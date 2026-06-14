class_name LevelPanel extends PanelContainer

signal play_clicked

@export_multiline var title_text: String = "Level 01"
@export_multiline var description_text: String = "PLACEHOLDER"
@export var play_button_text: String = "Play"
@export var play_button_disabled: bool = false


@onready var title_label: Label = %Title
@onready var description_label: RichTextLabel = %Description
@onready var play_button: Button = %PlayButton

func _ready() -> void:
	call_deferred("_apply_content")

func _apply_content() -> void:
	title_label.text = title_text
	description_label.text = description_text
	play_button.text = play_button_text
	play_button.disabled = play_button_disabled

func _on_play_button_pressed() -> void:
	if play_button.disabled:
		return
	play_clicked.emit()
