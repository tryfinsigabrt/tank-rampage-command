extends PanelContainer

signal back_requested

@onready var master_slider: HSlider = %MasterSlider
@onready var menu_slider: HSlider = %MenuSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var voice_slider: HSlider = %VoiceSlider
@onready var show_fps_check_button: CheckButton = %ShowFpsCheckButton

func _ready() -> void:
	_sync_from_settings()

func _sync_from_settings() -> void:
	master_slider.value = PlayerSettings.get_bus_volume(&"Master")
	menu_slider.value = PlayerSettings.get_bus_volume(&"Menu")
	music_slider.value = PlayerSettings.get_bus_volume(&"Music")
	sfx_slider.value = PlayerSettings.get_bus_volume(&"Sfx")
	voice_slider.value = PlayerSettings.get_bus_volume(&"Voice")
	show_fps_check_button.button_pressed = PlayerSettings.get_show_fps()

func _on_master_slider_value_changed(value: float) -> void:
	PlayerSettings.set_bus_volume(&"Master", value)

func _on_menu_slider_value_changed(value: float) -> void:
	PlayerSettings.set_bus_volume(&"Menu", value)

func _on_music_slider_value_changed(value: float) -> void:
	PlayerSettings.set_bus_volume(&"Music", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	PlayerSettings.set_bus_volume(&"Sfx", value)

func _on_voice_slider_value_changed(value: float) -> void:
	PlayerSettings.set_bus_volume(&"Voice", value)

func _on_show_fps_check_button_toggled(toggled_on: bool) -> void:
	PlayerSettings.set_show_fps(toggled_on)

func _on_back_button_pressed() -> void:
	back_requested.emit()
