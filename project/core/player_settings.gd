extends Node

signal bus_volume_changed(bus_name: StringName, value: float)
signal show_fps_changed(value: bool)
signal shadow_quality_updated(value: int)

const MIN_LINEAR: float = 0.001
const MUTE_DB: float = -80.0
const AUDIO_BUSES: PackedStringArray = [&"Master", &"Menu", &"Music", &"Sfx", &"Voice"]

enum AntiAliasing {
	OFF,
	MSAA_2X,
	MSAA_4X,
}

enum ShadowQuality {
	LOW,
	MEDIUM,
	HIGH,
}

const SAVE_FILE = "user://tank_rampage_command_settings.save"

var _bus_volumes: Dictionary[StringName, float] = {}
var _show_fps := false
var _anti_aliasing: AntiAliasing = AntiAliasing.OFF
var _shadow_quality: ShadowQuality = ShadowQuality.MEDIUM
var _anisotropic_filtering: Viewport.AnisotropicFiltering = ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", Viewport.ANISOTROPY_4X)
var _scaling_3d: float = ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)
var _fsr_is_enabled: bool = false if ProjectSettings.get_setting("rendering/scaling_3d/mode", 0) == 0 else true
var _fsr_sharpness: float = ProjectSettings.get_setting("rendering/scaling_3d/fsr_sharpness", 0.2)
var _max_fps: int = Engine.max_fps ## 0 means uncapped

func _ready() -> void:
	for bus_name in AUDIO_BUSES:
		_bus_volumes[bus_name] = 1.0
	_apply_all_bus_volumes()
	set_anti_aliasing(_anti_aliasing)
	set_shadow_quality(_shadow_quality)
	set_anisotropic_filtering(_anisotropic_filtering)

func get_bus_volume(bus_name: StringName) -> float:
	return _bus_volumes.get(bus_name, 1.0)


func set_bus_volume(bus_name: StringName, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_bus_volumes[bus_name] = clamped
	_apply_bus_volume(bus_name)
	bus_volume_changed.emit(bus_name, clamped)
	_save_settings_data()


func get_show_fps() -> bool:
	return _show_fps


func set_show_fps(value: bool) -> void:
	if _show_fps == value:
		return
	_show_fps = value
	show_fps_changed.emit(_show_fps)
	_save_settings_data()


func get_anti_aliasing() -> AntiAliasing:
	return _anti_aliasing


func set_anti_aliasing(value: AntiAliasing) -> void:
	_anti_aliasing = value

	var viewport := get_tree().root
	if viewport == null:
		return

	match _anti_aliasing:
		AntiAliasing.OFF:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		AntiAliasing.MSAA_2X:
			viewport.msaa_3d = Viewport.MSAA_2X
		AntiAliasing.MSAA_4X:
			viewport.msaa_3d = Viewport.MSAA_4X
	_save_settings_data()


func get_shadow_quality() -> ShadowQuality:
	return _shadow_quality


func set_shadow_quality(value: ShadowQuality) -> void:
	_shadow_quality = value
	shadow_quality_updated.emit(_shadow_quality)
	_save_settings_data()

func get_anisotropic_filtering() -> Viewport.AnisotropicFiltering:
	return _anisotropic_filtering

func set_anisotropic_filtering(value: Viewport.AnisotropicFiltering) -> void:
	_anisotropic_filtering = value
	get_viewport().anisotropic_filtering_level = _anisotropic_filtering
	print("Aniso set to enum idx %s" % get_viewport().anisotropic_filtering_level)
	_save_settings_data()
	
func get_scaling_3d() -> float:
	return _scaling_3d

func set_scaling_3d(value: float) -> void:
	_scaling_3d = clampf(value, 0.2, 4.0)
	ProjectSettings.set_setting("rendering/scaling_3d/scale", _scaling_3d)
	get_viewport().scaling_3d_scale = _scaling_3d
	_save_settings_data()

func get_fsr_enabled() -> bool:
	return _fsr_is_enabled

func set_fsr(enabled: bool) -> void:
	_fsr_is_enabled = enabled
	
	if _fsr_is_enabled:
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	else:
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_save_settings_data()

func get_fsr_sharpness() -> float: # 0.0 to 1.0
	var fsr_sharpness: float = get_viewport().fsr_sharpness
	return 1.0 - (fsr_sharpness / 2.0)

func set_fsr_sharpness(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_fsr_sharpness = value
	var remapped: float = remap(_fsr_sharpness, 0.0, 1.0, 2.0, 0.0)
	get_viewport().fsr_sharpness = remapped
	print("FSR sharpness set to %.2f percent, actual value %.2f" % [_fsr_sharpness, remapped])
	_save_settings_data()

func get_max_fps() -> int:
	return _max_fps

func set_max_fps(value: int) -> void:
	_max_fps = maxi(value, 0)
	Engine.max_fps = _max_fps
	_save_settings_data()

func get_ui_scale() -> float:
	return ProjectSettings.get_setting("display/window/stretch/scale", 1.0)

func set_ui_scale(value: float) -> void:
	value = clampf(value, 0.2, 4.0)
	ProjectSettings.set_setting("display/window/stretch/scale", value)
	get_tree().root.content_scale_factor = value
	_save_settings_data()

func _apply_all_bus_volumes() -> void:
	for bus_name in AUDIO_BUSES:
		_apply_bus_volume(bus_name)


func _apply_bus_volume(bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Failed to find sound bus name: %s", bus_name)
		return

	var linear := get_bus_volume(bus_name)
	var volume_db := MUTE_DB if linear <= MIN_LINEAR else linear_to_db(linear)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func apply_settings(settings: Dictionary) -> void:
	print("[PlayerSettings] Applying Settings: ", settings)
	if settings.has("bus_volumes"):
		_bus_volumes = settings.get("bus_volumes")
		_apply_all_bus_volumes()
	if settings.has("show_fps"): set_show_fps(settings.get("show_fps"))
	if settings.has("fsr_enabled"): set_fsr(settings.get("fsr_enabled"))
	if settings.has("fsr_sharpness"): set_fsr_sharpness(settings.get("fsr_sharpness"))
	if settings.has("anti_aliasing"): set_anti_aliasing(settings.get("anti_aliasing"))
	if settings.has("shadow_quality"): set_shadow_quality(settings.get("shadow_quality"))
	if settings.has("anisotropic_filtering"): 
		set_anisotropic_filtering(settings.get("anisotropic_filtering"))
	if settings.has("scaling_3d"): set_scaling_3d(settings.get("scaling_3d"))
	if settings.has("max_fps"): set_max_fps(settings.get("max_fps"))


func _save_settings_data() -> void:
	# Overwrites the full file (not append)
	var save_file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	var settings := _build_settings_dict()
	var json_settings := JSON.stringify(settings)
	print("[PlayerSettings] Saving settings data as: ", json_settings)
	save_file.store_line(json_settings)


func _load_settings_data() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		push_warning("No save file detected! (This might be OK!)")
		return
	
	var save_file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	var json_settings := save_file.get_line()
	var settings: Dictionary = JSON.parse_string(json_settings)
	print("[PlayerSettings] Loaded settings: ", settings)
	if settings != null:
		apply_settings(settings)


func _build_settings_dict() -> Dictionary:
	var settings := {
		"bus_volumes": _bus_volumes,
		"show_fps" : get_show_fps(),
		"fsr_enabled": get_fsr_enabled(),
		"fsr_sharpness": get_fsr_sharpness(),
		"anti_aliasing": get_anti_aliasing(),
		"shadow_quality": get_shadow_quality(),
		"anisotropic_filtering": get_anisotropic_filtering(),
		"scaling_3d": get_scaling_3d(),
		"max_fps": get_max_fps(),
		"ui_scale": get_ui_scale(),
	}
	return settings
