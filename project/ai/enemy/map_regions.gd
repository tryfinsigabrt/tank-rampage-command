class_name MapRegions extends Node

@export
var region_size:float = 20.0

var regions:Array[MapRegion]

@export
var update_interval:float = 0.5

var _world_bounds:Rect2
var _region_dim:Vector2i

const INVALID_COORDS:Vector2i = Vector2i.MIN
const SQRT_TWO:float = sqrt(2.0)
const HALF_SQRT_TWO:float = SQRT_TWO * 0.5

var region_dims:Vector2i:
	get: return _region_dim
	
var valid:bool:
	get: return not regions.is_empty()
	
func _ready() -> void:
	var world_boundaries:WorldBoundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries) as WorldBoundaries
	if not world_boundaries:
		push_error("%s: No world boundaries node in the tree!  Map regions cannot be computed" % name)
		return
	_build_regions(world_boundaries)
		
func is_region_visible(region:MapRegion) -> bool:
	var current_time:float = GameManager.game_timer.time_seconds
	var last_visible_time:float = region.last_visible_game_time
	return last_visible_time + update_interval * 1.1 > current_time
	
func get_region_at(world_location:Vector3) -> MapRegion:
	var region_coords:Vector2i = _world_location_to_grid_location(world_location)
	if region_coords.x < 0 or region_coords.y < 0 or region_coords.x >= _region_dim.x or region_coords.y >= _region_dim.y:
		return null
		
	# Already validated that above coords are in range
	var index:int = _coords_to_index(region_coords)
	assert(index >= 0 and index < regions.size(), 
		"%s: index=%d is out of region with size=%d; world_location=%s; bounds=%s; coords=%s" % [ \
			name, index, regions.size(), world_location, _world_bounds, region_coords
		])
	return regions[index]

func _coords_to_index(region_coords:Vector2i) -> int:
	return region_coords.y * _region_dim.x + region_coords.x

func index_to_coords(index:int) -> Vector2i:
	var width:int = _region_dim.x
	@warning_ignore("integer_division")
	var y:int = index / width
	var x:int = index % width
	
	return Vector2i(x, y)

func get_region_extent(row_major_regions:Array[MapRegion]) -> Vector2i:
	if row_major_regions.size() < 2:
		return Vector2i.ZERO
	
	# Compute indices of first and last to get the extents and then fill in the rest
	var min_coords:Vector2i = index_to_coords(row_major_regions.front().index)
	var max_coords:Vector2i = index_to_coords(row_major_regions.back().index)
	
	return max_coords - min_coords
	
func get_region_coords(row_major_regions:Array[MapRegion]) -> Array[Vector2i]:
	var indices:Array[Vector2i]
	if not row_major_regions:
		return indices
	
	var size:int = row_major_regions.size()
	indices.resize(size)
	
	# Compute indices of first and last to get the extents and then fill in the rest
	var min_coords:Vector2i = index_to_coords(row_major_regions.front().index)
	indices[0] = min_coords
	if size == 1:
		return indices
	
	var max_coords:Vector2i = index_to_coords(row_major_regions.back().index)
	if size == 2:
		indices[-1] = max_coords
		return indices
	
	var num_cols:int = max_coords.x - min_coords.x + 1
	var num_rows:int = max_coords.y - min_coords.y + 1
	
	for i in range(num_rows):
		var offset:int = i * num_cols
		for j in range(num_cols):
			indices[offset + j] = min_coords + Vector2i(j, i)
		
	return indices
	
func get_regions_for(world_location:Vector3, radius:float) -> Array[MapRegion]:
	var matching_regions:Array[MapRegion]
	
	# inscribed square size is r * sqrt(2) which is more conservative than circumscribed that would include some invisible areas
	var world_extent_size:float = radius * HALF_SQRT_TWO
	var world_extent:Vector2 = Vector2(world_extent_size, world_extent_size)
	var grid_center:Vector2 = MathUtils.grid_vector(world_location)
	
	var min_pos:Vector2 = grid_center - world_extent
	var max_pos:Vector2 = grid_center + world_extent
		
	var min_indices:Vector2i = _world_grid_location_to_grid_location(min_pos)
	# Include the max indices since this is a valid position
	var max_indices:Vector2i = _world_grid_location_to_grid_location(max_pos) + Vector2i.ONE
	
	# Clamp - here max is out of bounds to work cleaner with range
	min_indices = min_indices.clamp(Vector2i.ZERO, _region_dim)
	max_indices = max_indices.clamp(Vector2i.ZERO, _region_dim)
	
	for y in range(min_indices.y, max_indices.y):
		for x in range(min_indices.x, max_indices.x):
			matching_regions.push_back(regions[_coords_to_index(Vector2i(x, y))])
	return matching_regions
		
func _world_location_to_grid_location(world_location:Vector3) -> Vector2i:
	return _world_grid_location_to_grid_location(MathUtils.grid_vector(world_location))
	
func _world_grid_location_to_grid_location(grid_pos:Vector2) -> Vector2i:
	var bounds_pos:Vector2 = grid_pos - _world_bounds.position
	return Vector2i(
		floori(bounds_pos.x / region_size),
		floori(bounds_pos.y / region_size)
	)
	
func _build_regions(world_boundaries:WorldBoundaries) -> void:
	var world_aabb:AABB = world_boundaries.bounds
	if not world_aabb.has_volume():
		push_error("%s: World Boundaries has no volume - is the node in the right order in tree?" % name)
		return
	
	var aabb_pos:Vector3 = world_aabb.position
	var aabb_size:Vector3 = world_aabb.size
	
	_world_bounds.position = MathUtils.grid_vector(aabb_pos)
	_world_bounds.size = MathUtils.grid_vector(aabb_size)
	
	var size:Vector2 = _world_bounds.size
	
	_region_dim = Vector2i(ceili(size.x / region_size), ceili(size.y / region_size))
	
	# Preallocate
	var total_size:int = _region_dim.x * _region_dim.y
	regions.resize(total_size)
	var grid_size:Vector2 = Vector2(region_size,region_size)
	
	for y in _region_dim.y:
		var y_coord:float = y * region_size
		for x in _region_dim.x:
			var index:int = _coords_to_index(Vector2i(x, y))
			var pos:Vector2 = _world_bounds.position + Vector2(x * region_size, y_coord)
			regions[index] = MapRegion.new(index, Rect2(pos, grid_size))
