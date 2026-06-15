extends Node

signal bus_volume_changed(bus_name: StringName, value: float)

const MIN_LINEAR: float = 0.001
const MUTE_DB: float = -80.0
const AUDIO_BUSES: PackedStringArray = [&"Master", &"Menu", &"Music", &"Sfx", &"Voice"]

var _bus_volumes: Dictionary[StringName, float] = {}

func _ready() -> void:
	for bus_name in AUDIO_BUSES:
		_bus_volumes[bus_name] = 1.0
	_apply_all_bus_volumes()

func get_bus_volume(bus_name: StringName) -> float:
	return _bus_volumes.get(bus_name, 1.0)

func set_bus_volume(bus_name: StringName, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_bus_volumes[bus_name] = clamped
	_apply_bus_volume(bus_name)
	bus_volume_changed.emit(bus_name, clamped)

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
