extends Node

signal bus_volume_changed(bus_name: StringName, value: float)
signal show_fps_changed(value: bool)

const MIN_LINEAR: float = 0.001
const MUTE_DB: float = -80.0
const AUDIO_BUSES: PackedStringArray = [&"Master", &"Menu", &"Music", &"Sfx", &"Voice"]

enum AntiAliasing {
	OFF,
	MSAA_2X,
	MSAA_4X,
}

var _bus_volumes: Dictionary[StringName, float] = {}
var _show_fps := false
var _anti_aliasing: AntiAliasing = AntiAliasing.OFF

func _ready() -> void:
	for bus_name in AUDIO_BUSES:
		_bus_volumes[bus_name] = 1.0
	_apply_all_bus_volumes()
	set_anti_aliasing(_anti_aliasing)


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
