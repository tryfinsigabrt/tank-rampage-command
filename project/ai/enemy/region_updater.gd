extends Node

@export
var map_regions:MapRegions

@onready var tick_timer: Timer = $TickTimer
@onready var cache_cleanup_timer: Timer = $CacheCleanupTimer

var _match_team:MatchTeam

class CacheEntry:
	var pos:Vector3 = Vector3.INF
	var vision:float = -1.0
	var pos_region:MapRegion
	var visible_regions:Array[MapRegion]
	
var _region_cache:Dictionary[int, CacheEntry]

func _ready() -> void:
	_match_team = Groups.get_parent_in_group(self, Groups.MatchTeam)
	if not _match_team:
		push_error("%s: Map region not put in a MatchTeam tree" % name)
		queue_free()
		return
	
	tick_timer.wait_time = map_regions.update_interval
	tick_timer.start()
	
	cache_cleanup_timer.start()
	
func _tick() -> void:
	var time:float = GameManager.game_timer.time_seconds
		
	for asset in _match_team:
		var team_component := TeamComponent.get_component(asset, false)
		if not team_component:
			continue
		var vision:float = team_component.vision
		if vision <= 0:
			continue
		
		var instance_id:int = asset.get_instance_id()
		var cache_entry:CacheEntry = _region_cache.get(instance_id)
		var cache_valid:bool = false
		
		var pos:Vector3 = asset.global_position

		if cache_entry:
			cache_valid = cache_entry.pos.distance_squared_to(pos) < 1.0 and is_equal_approx(vision, cache_entry.vision)
		else:
			cache_entry = CacheEntry.new()
			_region_cache[instance_id] = cache_entry
		
		if not cache_valid:
			cache_entry.pos = pos
			cache_entry.vision = vision
			
		if asset is Unit:
			var pos_region:MapRegion
			if cache_valid:
				pos_region = cache_entry.pos_region
			else:
				pos_region = map_regions.get_region_at(pos)
				cache_entry.pos_region = pos_region
				
			if pos_region:
				pos_region.navigable = true
			
		# Update visible regions
		var visible_regions:Array[MapRegion]
		if cache_valid:
			visible_regions = cache_entry.visible_regions
		else:
			visible_regions = map_regions.get_regions_for(pos, vision)
			cache_entry.visible_regions = visible_regions
		
		for region in visible_regions:
			region.explored = true
			region.last_visible_game_time = time
	# For all assets

func _cleanup_cache() -> void:
	var invalid_cache_keys:PackedInt64Array
	for key in _region_cache:
		if not is_instance_id_valid(key):
			invalid_cache_keys.push_back(key)
	for invalid_key in invalid_cache_keys:
		_region_cache.clear()
