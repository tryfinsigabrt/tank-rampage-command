extends Node

@export
var map_regions:MapRegions

var _match_team:MatchTeam

var _visible_markers:PackedByteArray

class CacheEntry:
	var pos:Vector3
	var vision:float
	var pos_region:MapRegion
	var visible_regions:Array[MapRegion]
	
var _region_cache:Dictionary[int, CacheEntry]

func _ready() -> void:
	_match_team = Groups.get_parent_in_group(self, Groups.MatchTeam)
	if not _match_team:
		push_error("%s: Map region not put in a MatchTeam tree" % name)
		queue_free()
		return
	await NodeUtils.ensure_ready(map_regions)
	
	_visible_markers.resize(map_regions.regions.size())
	
func _tick() -> void:
	if not _visible_markers:
		return
		
	var time:float = GameManager.game_timer.time_seconds
	_visible_markers.fill(0)
		
	for asset in _match_team.assets:
		var team_component := TeamComponent.get_component(asset, false)
		if not team_component:
			continue
		var vision:float = team_component.vision
		if vision <= 0:
			continue
		var pos:Vector3 = asset.global_position
		
		var instance_id:int = asset.get_instance_id()
		var cache_entry:CacheEntry = _region_cache.get(instance_id)
		var cache_valid:bool = false
		
		if cache_entry:
			cache_valid = cache_entry.pos.is_equal_approx(pos) and is_equal_approx(vision, cache_entry.vision)
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
			
		# Update all regions
		var visible_regions:Array[MapRegion]
		if cache_valid:
			visible_regions = cache_entry.visible_regions
		else:
			visible_regions = map_regions.get_regions_for(pos, vision)
			cache_entry.visible_regions = visible_regions
		
		for region in visible_regions:
			region.explored = true
			region.last_visible_game_time = time
			_visible_markers[region.index] = 1
	# For all assets
	
	# Update all visibility from marked visible regions
	var all_regions := map_regions.regions
	for index in _visible_markers.size():
		all_regions[index].visible = _visible_markers[index]

func _cleanup_cache() -> void:
	var invalid_cache_keys:PackedInt64Array
	for key in _region_cache:
		if not is_instance_id_valid(key):
			invalid_cache_keys.push_back(key)
	for invalid_key in invalid_cache_keys:
		_region_cache.clear()
