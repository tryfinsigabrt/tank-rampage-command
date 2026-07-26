extends PanelContainer

signal back_requested

@onready var master_slider: HSlider = %MasterSlider
@onready var menu_slider: HSlider = %MenuSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var voice_slider: HSlider = %VoiceSlider
@onready var show_fps_check_button: CheckButton = %ShowFpsCheckButton
@onready var anti_aliasing_option_button: OptionButton = %AntiAliasingOptionButton
@onready var shadow_quality_option_button: OptionButton = %ShadowQualityOptionButton
@onready var aniso_option_button: OptionButton = %AnisoOptionButton
@onready var scaling_3d_spinbox: SpinBox = %Scaling3DSpinbox
@onready var fps_spinbox: SpinBox = %FPSSpinbox


func _ready() -> void:
	hide()
	_populate_anti_aliasing_options()
	_populate_shadow_quality_options()
	_sync_from_settings()
	
func _on_back_button_pressed() -> void:
	back_requested.emit()

func _sync_from_settings() -> void:
	master_slider.value = PlayerSettings.get_bus_volume(&"Master")
	menu_slider.value = PlayerSettings.get_bus_volume(&"Menu")
	music_slider.value = PlayerSettings.get_bus_volume(&"Music")
	sfx_slider.value = PlayerSettings.get_bus_volume(&"Sfx")
	voice_slider.value = PlayerSettings.get_bus_volume(&"Voice")
	show_fps_check_button.button_pressed = PlayerSettings.get_show_fps()
	anti_aliasing_option_button.select(PlayerSettings.get_anti_aliasing())
	shadow_quality_option_button.select(PlayerSettings.get_shadow_quality())
	aniso_option_button.select(PlayerSettings.get_anisotropic_filtering())
	scaling_3d_spinbox.set_value_no_signal(PlayerSettings.get_scaling_3d())
	fps_spinbox.set_value_no_signal(Engine.max_fps)

func _populate_anti_aliasing_options() -> void:
	anti_aliasing_option_button.clear()
	anti_aliasing_option_button.add_item("Off", PlayerSettings.AntiAliasing.OFF)
	anti_aliasing_option_button.add_item("MSAA 2x", PlayerSettings.AntiAliasing.MSAA_2X)
	anti_aliasing_option_button.add_item("MSAA 4x", PlayerSettings.AntiAliasing.MSAA_4X)


func _populate_shadow_quality_options() -> void:
	shadow_quality_option_button.clear()
	shadow_quality_option_button.add_item("Low", PlayerSettings.ShadowQuality.LOW)
	shadow_quality_option_button.add_item("Medium", PlayerSettings.ShadowQuality.MEDIUM)
	shadow_quality_option_button.add_item("High", PlayerSettings.ShadowQuality.HIGH)

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

func _on_anti_aliasing_option_button_item_selected(index: int) -> void:
	PlayerSettings.set_anti_aliasing(anti_aliasing_option_button.get_item_id(index) as PlayerSettings.AntiAliasing)

func _on_shadow_quality_option_button_item_selected(index: int) -> void:
	PlayerSettings.set_shadow_quality(shadow_quality_option_button.get_item_id(index) as PlayerSettings.ShadowQuality)
	
func _on_anisotropic_filtering_selected(idx: int) -> void:
	PlayerSettings.set_anisotropic_filtering(aniso_option_button.get_item_id(idx) as Viewport.AnisotropicFiltering)

func _on_scaling_3d_spinbox_value_changed(value: float) -> void:
	PlayerSettings.set_scaling_3d(value)

func _on_fps_spinbox_value_changed(value: float) -> void:
	PlayerSettings.set_max_fps(int(value))
