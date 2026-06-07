extends Node
class_name MenuAudio

const BUTTON_HOVER_STREAM: AudioStream = preload("res://sounds/ui_cursor_hover.wav")
const BUTTON_SELECT_STREAM: AudioStream = preload("res://sounds/ui_cursor_select.wav")

static var _button_signal_audio_streams: Dictionary[StringName, AudioStream]

@onready var _menu_audio_player: AudioStreamPlayer = $MenuAudioPlayer

func _ready() -> void:
	assign_all_menu_button_audio()
	
func assign_all_menu_button_audio() -> void:
	var buttons: Array[Node] = get_parent().find_children("*", "Button", true, false)
	for button in buttons:
		button.pressed.connect(_on_button_event.bind(button, &"pressed"))
		button.mouse_entered.connect(_on_button_event.bind(button, &"mouse_entered"))

		var select_stream_key:StringName = button.name + "|" + "pressed"
		_button_signal_audio_streams[select_stream_key] = BUTTON_SELECT_STREAM

		var hover_stream_key:StringName = button.name + "|" + "mouse_entered"
		_button_signal_audio_streams[hover_stream_key] = BUTTON_HOVER_STREAM

func _on_button_event(button: Button, signal_name: String) -> void:
	var stream_key:StringName = button.name + "|" + signal_name
	if stream_key:
		if _menu_audio_player.stream:
			_menu_audio_player.stop()

		_menu_audio_player.stream = _button_signal_audio_streams[stream_key]
		if _menu_audio_player.stream:
			_menu_audio_player.play()
