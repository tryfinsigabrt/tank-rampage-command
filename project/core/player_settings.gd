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

var _bus_volumes: Dictionary[StringName, float] = {}
var _show_fps := false
var _anti_aliasing: AntiAliasing = AntiAliasing.OFF
var _shadow_quality: ShadowQuality = ShadowQuality.MEDIUM
var _anisotropic_filtering: Viewport.AnisotropicFiltering = ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", Viewport.ANISOTROPY_4X)
var _scaling_3d: float = ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)
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


func get_show_fps() -> bool:
	return _show_fps


func set_show_fps(value: bool) -> void:
	if _show_fps == value:
		return
	_show_fps = value
	show_fps_changed.emit(_show_fps)


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


func get_shadow_quality() -> ShadowQuality:
	return _shadow_quality


func set_shadow_quality(value: ShadowQuality) -> void:
	_shadow_quality = value
	shadow_quality_updated.emit(_shadow_quality)

func get_anisotropic_filtering() -> Viewport.AnisotropicFiltering:
	return _anisotropic_filtering

func set_anisotropic_filtering(value: Viewport.AnisotropicFiltering) -> void:
	_anisotropic_filtering = value
	get_viewport().anisotropic_filtering_level = _anisotropic_filtering
	print("Aniso set to enum idx %s" % get_viewport().anisotropic_filtering_level)
	
func get_scaling_3d() -> float:
	return _scaling_3d

func set_scaling_3d(value: float) -> void:
	_scaling_3d = clampf(value, 0.2, 4.0)
	ProjectSettings.set_setting("rendering/scaling_3d/scale", _scaling_3d)
	get_viewport().scaling_3d_scale = _scaling_3d

func get_max_fps() -> int:
	return _max_fps

func set_max_fps(value: int) -> void:
	_max_fps = maxi(value, 0)
	Engine.max_fps = _max_fps

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
