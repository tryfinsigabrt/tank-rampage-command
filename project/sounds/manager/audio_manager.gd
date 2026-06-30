## Audio Manager for managing game sounds and audio concurrency across different sound buses
class_name AudioManager extends Node

@export
var config: AudioManagerConfig

@onready var legacy_behavior: AudioManagerLegacy = %LegacyBehavior
@onready var _pools: Node = %Pools

## Will be removed after AudioManager pool integration is complete
var _pools_by_key:Dictionary[String, AudioPlayerPool]

#region Legacy Behavior
## Plays a one-shot sound that is level-bound so should survive it's current parent node attachment
## Any node can be provided that has a "play" function that takes no arguments
## This could be an AudioStreamPlayer3D or AudioStreamPlayer
func play_level_sound(playable_node:Node) -> void:
	legacy_behavior.play_level_sound(playable_node)
#endregion

func play_3d(player_config:AudioPlayerConfig, position:Vector3) -> void:
	if not player_config or not player_config.valid:
		return
	
	var pool:AudioPlayerPool3D = _get_pool_for(player_config, AudioManagerConfigEntry.Type.Player3D)
	pool.play(player_config, position)
	
func play_3d_attached(player_config:AudioPlayerConfig, node:Node3D) -> void:
	if not player_config or not player_config.valid:
		return
	
	var pool:AudioPlayerPool3D = _get_pool_for(player_config, AudioManagerConfigEntry.Type.Player3D)
	pool.play_attached(player_config, node) 

func play_global(player_config:AudioPlayerConfig) -> void:
	if not player_config or not player_config.valid:
		return
	
	var pool:AudioPlayerPoolGlobal = _get_pool_for(player_config, AudioManagerConfigEntry.Type.PlayerNonSpatial)
	pool.play(player_config)

func _get_pool_for(player_config:AudioPlayerConfig, type:AudioManagerConfigEntry.Type) -> AudioPlayerPool:
	var group:String = player_config.group
	var pool:AudioPlayerPool = null
	
	if group:
		var full_key:String = AudioManagerConfigEntry.create_key(player_config.bus, type, group)
		pool = _pools_by_key.get(full_key)
		if pool:
			if OS.is_debug_build():
				print_debug("%s: Selected pool %s with full_key=%s" % [name, pool.name, full_key])
			return pool
			
	var bus_key:String = AudioManagerConfigEntry.create_key(player_config.bus, type)
	pool = _pools_by_key.get(bus_key)
	if pool:
		if OS.is_debug_build():
			print_debug("%s: Selected pool %s with bus_key=%s" % [name, pool.name, bus_key])
		return pool
	
	push_warning("%s: Could not find audio pool for config=%s with bus=%s; type=%d; group=%s = creating new default pool dynamically" % 
		[name, player_config, player_config.bus, EnumUtils.enum_to_string(AudioManagerConfigEntry.Type, type), group])
	
	var default_entry := AudioManagerConfigEntry.new()
	default_entry.bus = player_config.bus
	default_entry.group = group
	default_entry.type = type
	
	pool = _create_pool(default_entry)
	
	return pool
	
func _ready() -> void:
	if not config:
		push_warning("%s: No AudioManagerConfig set - will use defaults for each bus" % name)
		config = AudioManagerConfig.new()
	
	var entries := config.entries
	for i in entries.size():
		var entry := entries[i]
		
		var bus_only_key:String = entry.bus_only_key
		var key:String = entry.key
		
		if key in _pools_by_key:
			push_warning("%s: Attempted to add duplicate bus/group combo %s at index %d" % [name, key, i])
			continue
			
		var player:AudioPlayerPool = _create_pool(entry)
		_pools_by_key[key] = player
		
		# Also add a bus only entry if key is distinct from it
		if bus_only_key not in _pools_by_key:
			_pools_by_key[bus_only_key] = player
		
func _create_pool(in_config: AudioManagerConfigEntry) -> AudioPlayerPool:
	var player:AudioPlayerPool
	
	match in_config.type:
		AudioManagerConfigEntry.Type.Player3D:
			player = AudioPlayerPool3D.new()
		AudioManagerConfigEntry.Type.PlayerNonSpatial:
			player = AudioPlayerPoolGlobal.new()
		_:
			push_warning("%s: Unsupported type %s specified - defaulting to non spatial" % 
				[name, EnumUtils.enum_to_string(AudioManagerConfigEntry.Type, in_config.type)])
			player = AudioPlayerPoolGlobal.new()
			
	player.config = in_config
	player.name = "AudioPool%s%s" % [EnumUtils.enum_to_string(AudioManagerConfigEntry.Type, in_config.type), in_config.key]
	
	_pools.add_child(player)
	return player		
