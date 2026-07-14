extends PanelContainer

const DEFAULT_NEXT_TEXT := "Next"

@export_multiline var message_text: String = "":
	set(value):
		message_text = value
		if is_node_ready():
			_apply_message()

@onready var message_label: RichTextLabel = %MessageLabel
@onready var next_button: Button = %NextButton

func _ready() -> void:
	_apply_message()
	set_next_button_state(DEFAULT_NEXT_TEXT, false)

func _apply_message() -> void:
	message_label.text = message_text

func show_message(new_message_text: String) -> void:
	message_text = new_message_text
	set_next_button_state(DEFAULT_NEXT_TEXT, false)
	visible = true

func clear_message() -> void:
	message_text = ""
	set_next_button_state(DEFAULT_NEXT_TEXT, false)
	visible = false

func set_next_button_state(button_text: String, disabled: bool) -> void:
	next_button.text = button_text if not button_text.is_empty() else DEFAULT_NEXT_TEXT
	next_button.disabled = disabled

func _on_next_button_pressed() -> void:
	SignalBus.on_player_message_next_clicked.emit()
