## CPU-side replica of the fog-of-war visible/explored computation done on the
## GPU by visibility_multi_mesh.gd + fow_explored_area.gdshader.
##
## Gameplay visibility queries (NodeVisibilityManager, placement checks) read
## this model instead of reading the SubViewport texture back from the GPU
## (ViewportTexture.get_image), which stalls the render pipeline (~28ms per
## readback). The viewport textures remain render-only for the fog visuals.
##
## Each player-team asset reveals an axis-aligned square of side
## TeamComponent.vision world units — the 1x1 quad the MultiMesh renders scaled
## by vision — expanded by an edge tolerance that approximates the shader's
## box blur combined with the visible-channel threshold.
class_name FowVisibilityModel extends RefCounted

## Bounds for the self-tuned spatial hash cell size
const MIN_VISIBLE_GRID_CELL_SIZE:float = 64.0
const MAX_VISIBLE_GRID_CELL_SIZE:float = 512.0

var _world_origin:Vector2
var _world_size:Vector2

# Snapshot of vision sources (player-team assets) taken each fow tick
var _source_centers:PackedVector2Array
var _source_half_extents:PackedFloat32Array
# Spatial hash: cell -> indices of sources whose vision squares overlap it.
# Sources are inserted into every cell their square overlaps so a query only
# ever needs to inspect the single cell containing the query point.
var _visible_grid: Dictionary[Vector2i, PackedInt32Array] = {}
# Cell size of the spatial hash, re-derived each update from the largest
# vision square in play so it stays balanced if vision values are rebalanced
var _visible_grid_cell_size:float = MIN_VISIBLE_GRID_CELL_SIZE

# Explored-area accumulation grid (byte per cell, non-zero = explored),
# mirroring the green channel the explored-area shader accumulates
var _explored_cell_size:float = 4.0
var _explored_dims:Vector2i
var _explored:PackedByteArray

# Last stamped center per source instance id so stationary sources
# (buildings, idle units) don't re-stamp the explored grid every tick
var _last_stamp_positions: Dictionary[int, Vector2] = {}
var _last_edge_tolerance:float = 0.0

func configure(world_aabb:AABB, explored_cell_size:float) -> void:
	_world_origin = Vector2(world_aabb.position.x, world_aabb.position.z)
	_world_size = Vector2(world_aabb.size.x, world_aabb.size.z)
	_explored_cell_size = maxf(explored_cell_size, 0.5)
	_explored_dims = Vector2i(
		maxi(ceili(_world_size.x / _explored_cell_size), 1),
		maxi(ceili(_world_size.y / _explored_cell_size), 1)
	)
	clear_explored()

func clear_explored() -> void:
	_explored.resize(_explored_dims.x * _explored_dims.y)
	_explored.fill(0)
	_last_stamp_positions.clear()

## Rebuild the source snapshot and spatial hash from the currently registered
## player-team assets. Call on the same tick the visibility MultiMesh is
## updated so gameplay queries agree with what the fog visuals show.
func update(nodes:Array[Node3D], edge_tolerance:float) -> void:
	var max_count:int = nodes.size()
	_source_centers.resize(max_count)
	_source_half_extents.resize(max_count)
	_visible_grid.clear()
	_last_edge_tolerance = edge_tolerance

	var stamped: Dictionary[int, Vector2] = {}
	var move_threshold_sq:float = _explored_cell_size * _explored_cell_size * 0.25
	var max_half_extent:float = 0.0
	var count:int = 0

	for node in nodes:
		if not is_instance_valid(node) or not node.is_in_group(Groups.TeamAsset):
			continue

		var pos:Vector3 = node.global_position
		var center:Vector2 = Vector2(pos.x, pos.z)
		# The MultiMesh renders a 1x1 quad scaled by the vision value so the
		# revealed square has a half extent of half that value
		var half_extent:float = node.team_component.vision * 0.5 + edge_tolerance

		_source_centers[count] = center
		_source_half_extents[count] = half_extent
		max_half_extent = maxf(max_half_extent, half_extent)
		count += 1

		var id:int = node.get_instance_id()
		if not _last_stamp_positions.has(id) \
				or _last_stamp_positions[id].distance_squared_to(center) > move_threshold_sq:
			_stamp_explored(center, half_extent)
			stamped[id] = center
		else:
			stamped[id] = _last_stamp_positions[id]

	# Replacing the dictionary also drops entries for freed/removed sources
	_last_stamp_positions = stamped
	_source_centers.resize(count)
	_source_half_extents.resize(count)

	# Self-tune the hash cell to the largest vision square in play so each
	# source overlaps only a handful of cells while cells stay small enough
	# that queries test few candidates
	_visible_grid_cell_size = clampf(max_half_extent, MIN_VISIBLE_GRID_CELL_SIZE, MAX_VISIBLE_GRID_CELL_SIZE)
	for i in count:
		_insert_into_visible_grid(i, _source_centers[i], _source_half_extents[i])

func is_position_visible(pos:Vector3) -> bool:
	var point:Vector2 = Vector2(pos.x, pos.z)
	var cell:Vector2i = Vector2i((point / _visible_grid_cell_size).floor())
	if not _visible_grid.has(cell):
		return false

	var indices:PackedInt32Array = _visible_grid[cell]
	for i in indices:
		var center:Vector2 = _source_centers[i]
		# TODO: Experiment with modulating the half_extent with a tolerance factor [0,1] that scales the _last_edge_tolerance
		# This does risk introducing bucketing errors and so currently the average case is taken into account with an edge_tolerance_scale in fog_of_war
		# and computed during update
		var half_extent:float = _source_half_extents[i]
		if absf(point.x - center.x) <= half_extent and absf(point.y - center.y) <= half_extent:
			return true
	return false

func is_position_explored(pos:Vector3) -> bool:
	if _explored.is_empty():
		return false

	var local:Vector2 = (Vector2(pos.x, pos.z) - _world_origin) / _explored_cell_size
	var cell_x:int = floori(local.x)
	var cell_y:int = floori(local.y)
	if cell_x < 0 or cell_x >= _explored_dims.x or cell_y < 0 or cell_y >= _explored_dims.y:
		return false
	return _explored[cell_y * _explored_dims.x + cell_x] != 0

func _insert_into_visible_grid(index:int, center:Vector2, half_extent:float) -> void:
	var extents:Vector2 = Vector2(half_extent, half_extent)
	var min_cell:Vector2i = Vector2i(((center - extents) / _visible_grid_cell_size).floor())
	var max_cell:Vector2i = Vector2i(((center + extents) / _visible_grid_cell_size).floor())

	for cell_y in range(min_cell.y, max_cell.y + 1):
		for cell_x in range(min_cell.x, max_cell.x + 1):
			var cell:Vector2i = Vector2i(cell_x, cell_y)
			if _visible_grid.has(cell):
				_visible_grid[cell].push_back(index)
			else:
				_visible_grid[cell] = PackedInt32Array([index])

func _stamp_explored(center:Vector2, half_extent:float) -> void:
	if _explored.is_empty():
		return

	var local_min:Vector2 = (center - Vector2(half_extent, half_extent) - _world_origin) / _explored_cell_size
	var local_max:Vector2 = (center + Vector2(half_extent, half_extent) - _world_origin) / _explored_cell_size

	# Skip squares entirely outside the map before clamping to the grid
	if local_max.x < 0.0 or local_max.y < 0.0 \
			or local_min.x >= float(_explored_dims.x) or local_min.y >= float(_explored_dims.y):
		return

	var min_x:int = clampi(floori(local_min.x), 0, _explored_dims.x - 1)
	var max_x:int = clampi(floori(local_max.x), 0, _explored_dims.x - 1)
	var min_y:int = clampi(floori(local_min.y), 0, _explored_dims.y - 1)
	var max_y:int = clampi(floori(local_max.y), 0, _explored_dims.y - 1)

	for cell_y in range(min_y, max_y + 1):
		var row_start:int = cell_y * _explored_dims.x
		for cell_x in range(min_x, max_x + 1):
			_explored[row_start + cell_x] = 1
