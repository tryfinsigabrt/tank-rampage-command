extends PanelContainer

@export_multiline var message_text: String = "":
	set(value):
		message_text = value
		if is_node_ready():
			_apply_message()

@onready var message_label: RichTextLabel = %MessageLabel
@onready var next_button: Button = %NextButton

func _ready() -> void:
	_apply_message()

func _apply_message() -> void:
	message_label.text = message_text

func show_message(new_message_text: String) -> void:
	message_text = new_message_text
	visible = true

func clear_message() -> void:
	message_text = ""
	visible = false

func _on_next_button_pressed() -> void:
	SignalBus.on_player_message_next_clicked.emit()
