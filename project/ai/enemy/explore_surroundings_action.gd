@tool
extends ActionLeaf

@export
var default_move_radius:Vector2 = Vector2(100, 250)

@export
var heading_variation_degrees:Vector2 = Vector2(30,120)

@export
var world_boundaries_checker:WorldBoundariesChecker

## Prefer exploring as a group up to the max size
@export
var max_group_size:int = 10

const MAX_ATTEMPTS:int = 8

@export
var preferred_unit_group_proximity:float = 100.0

@export
var min_unit_group_proximity:float = 25.0

@export
var enable_map_region_use:bool = true

@export
var map_region_score_random_threshold:float = 5.0

var _cluster_creator:ClusterCircleCreator = ClusterCircleCreator.new(preferred_unit_group_proximity)
	
var _blackboard:EnemyTeamBlackboard

const FOLLOWER_UNIT_CLASSES: Array[Unit.UnitClass] = [
	Unit.UnitClass.Artillery
]

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not world_boundaries_checker:
		push_warning("%s: WorldBoundariesChecker not set - no bounds testing on move targets!" % name)
		
func tick(_actor: Node, blackboard: Blackboard) -> int:	
	self._blackboard = blackboard
	
	var heading_bias_dict: Dictionary[int, Vector3] = _blackboard.explore_heading_bias
		
	for group in _get_unit_groups():
		var leader:Unit = null
		for unit:Unit in group:
			var unit_id:int = unit.get_instance_id()
			var heading_bias:Vector3 = heading_bias_dict.get(unit_id, Vector3.ZERO)
			if not leader or heading_bias:
				var target_pos:Vector3 = _select_move_target(unit, heading_bias)
				# Only select as leader if not getting a flee vector heading, and we didn't bail out and return a "non-move"
				if not heading_bias and not target_pos.is_equal_approx(unit.global_position):
					leader = unit
			# Provide assistance
			else:
				unit.get_or_add_actions().follow(leader)
						
	return SUCCESS
	
func _get_unit_groups() -> Array[Array]:
	var available_units:Array[Unit] = _get_available_units()
	var groups:Array[Array]
	if not available_units:
		return groups
	
	_cluster_creator.max_cluster_size = preferred_unit_group_proximity
	var clusters: Array[ClusterCircle] = _cluster_creator.compute_clusters(available_units)
	
	var i:int = 0
	while i < clusters.size():
		var cluster:ClusterCircle = clusters[i]
		# Subdivide
		while cluster.objects.size() > max_group_size and cluster.size > min_unit_group_proximity:
			_cluster_creator.max_cluster_size = cluster.size * 0.5
			var sub_clusters:Array[ClusterCircle] = _cluster_creator.compute_clusters(cluster.objects)
			cluster = sub_clusters[0]
			clusters[i] = cluster
			for j in range(1, sub_clusters.size()):
				clusters.push_back(sub_clusters[j])
		var units:Array = cluster.objects
		# Sort so that artillery units are last and will be followers
		units.sort_custom(func(a:Unit, b:Unit) -> bool:
			var a_follower:bool = a.unit_class in FOLLOWER_UNIT_CLASSES
			var b_follower:bool = b.unit_class in FOLLOWER_UNIT_CLASSES
			if a_follower != b_follower:
				# a not a follower so comes first
				return b_follower
			return true
		)
		groups.push_back(units)
		i += 1
		
	return groups
	
func _get_available_units() -> Array[Unit]:
	var candidate_units := _blackboard.idle_units
	var available_units:Array[Unit]
	available_units.resize(candidate_units.size())
	
	var count:int = 0
	for i in available_units.size():
		var unit:Variant = candidate_units[i]
		# TODO: Shouldn't have to do this - the monitor should be taking care of this but it's not working properly as still 
		# encounter "previously freed" - another approach would be to convert idle_units to just PackedInt64Array
		if not is_instance_valid(unit):
			continue
		
		# Also do not mark as available if the unit has another directive
		var directives:AiUnitDirectives = AiUnitDirectives.get_component(unit, false)
		if (directives and directives.enabled) or not unit.get_or_add_actions().is_idle():
			continue
		
		available_units[count] = unit
		count += 1
	available_units.resize(count)
	
	return available_units
	
func _select_move_target(unit:Unit, heading_bias:Vector3) -> Vector3:
	if LogUtils.debug:
		print_debug("%s: Select move target for unit=%s" % [name, unit.name])
	
	#var start:int = Time.get_ticks_usec()
	var target_pos:Vector3 = _get_move_target(unit, heading_bias)
	#var end:int = Time.get_ticks_usec()
	#print("%s: MOVE EXECUTION TIME(ms):%.3f" % [name, (end - start) / 1000.0])
	
	if heading_bias:
		unit.get_or_add_actions().move(target_pos)
	else:
		unit.get_or_add_actions().move_and_attack(target_pos)
	
	return target_pos

func _get_move_target(unit:Unit, heading_bias_raw:Vector3) -> Vector3:
	var target:Vector3
	if enable_map_region_use and _blackboard.map_regions.valid:
		target = _get_best_move_target(unit, heading_bias_raw)
		if not target.is_equal_approx(unit.global_position):
			return target
	
	return _get_randomized_move_target(unit, heading_bias_raw)
	
#region Map Region Move Target

class RegionScore:
	var region:MapRegion
	var score:float
	
	func _init(in_region:MapRegion) -> void:
		region = in_region
	
func _get_best_move_target(unit:Unit, heading_bias_raw:Vector3) -> Vector3:
	var unit_attributes:TeamAssetAttributes = unit.attributes
	var movement_range:Vector2 = unit_attributes.explore_range if unit_attributes else default_move_radius
	var move_radius:float = randf_range(movement_range.x, movement_range.y)
	
	var current_pos:Vector3 = unit.global_position
	
	var map_regions:MapRegions = _blackboard.map_regions
	var candidate_regions:Array[MapRegion] = map_regions.get_regions_for(current_pos, move_radius)
	
	if not candidate_regions:
		push_warning("%s: Could not get candidate regions for unit=%s: " % [name, unit.name])
		return current_pos
		
	var candidate_coords:Array[Vector2i] = map_regions.get_region_coords(candidate_regions)
	
	var region_scores:Array[RegionScore]
	region_scores.resize(candidate_regions.size())
	for i in candidate_regions.size():
		region_scores[i] = RegionScore.new(candidate_regions[i])
	
	# Offset all the region coords so they are relative coordinates
	var min_coord:Vector2i = candidate_coords.front()
	var max_coord:Vector2i = candidate_coords.back()
	
	# Now the dimensions will be the last element
	var coord_dim:Vector2i = max_coord - min_coord
	
	var current_pos_2d:Vector2 = MathUtils.grid_vector(current_pos)
	var max_dist_sq:float = move_radius * move_radius
	
	var all_regions:Array[MapRegion] = map_regions.regions
	var region_dims:Vector2i = map_regions.region_dims
		
	var time:float = GameManager.game_timer.time_seconds
	
	# Prefer furthest unexplored region that is navigable from adjacent
	for i in region_scores.size():
		var region_score := region_scores[i]
		var region := region_score.region
		var global_index:int = region.index
		
		var total_score:float = 0.0
		var area:Rect2 = region.area
		var dist_sq:float = area.position.distance_squared_to(current_pos_2d)
		var dist_score:float = dist_sq / max_dist_sq * 25.0
		total_score += dist_score
		
		# If area currently contains the unit then give it a penalty
		if area.has_point(current_pos_2d):
			total_score -= 20.0
		
		# If recently selected this position then reduce score
		if region.last_targeted_time > 0.0:
			var recency_penalty:float
			var delta_time:float = time - region.last_targeted_time
			if delta_time < 22.5:
				recency_penalty = 200.0
			else:
				recency_penalty = exp(120.0 / maxf(delta_time, 0.01))
			total_score -= recency_penalty
			
		# If unexplored then add a bonus if adjacent region is confirmed to be navigable which also implies explored
		if not region.explored:
			var region_coord:Vector2i = candidate_coords[i]
			# Has a left neighbor
			if region_coord.x > 0:
				var left_neighbor := all_regions[global_index - 1]
				if left_neighbor.navigable:
					total_score += 10.0
			# Has a right neighbor
			if region_coord.x < region_dims.x:
				var right_neighbor := all_regions[global_index + 1]
				if right_neighbor.navigable:
					total_score += 10.0
			# Has a top neighbor
			if region_coord.y > 0:
				var top_neighbor := all_regions[global_index - coord_dim.x]
				if top_neighbor.navigable:
					total_score += 10.0
			# Has a bottom neighbor
			if region_coord.y < region_dims.y:
				var top_neighbor := all_regions[global_index + coord_dim.x]
				if top_neighbor.navigable:
					total_score += 10.0
		# Explored but not visible regions get a boost since want to push out into non-visible areas
		elif not map_regions.is_region_visible(region):
			total_score += 7.5
		# Penalize visible areas
		else:
			total_score -= 15.0
		
		# if region is confirmed navigable get a boost	
		if region.navigable:
			total_score += 10.0
			
		region_score.score = total_score		
	# for every region score
	
	region_scores.sort_custom(func(a:RegionScore, b:RegionScore) -> bool:
		return a.score > b.score
	)
	var max_score:float = region_scores.front().score
	var max_sampling_index:int = 0
	for i in range(1, region_scores.size()):
		var score:float = region_scores[i].score
		if max_score - score <= map_region_score_random_threshold:
			max_sampling_index += 1
		else:
			break
			
	var selected_index:int = randi_range(0, max_sampling_index)
	var selected_region:MapRegion = candidate_regions[selected_index]
	selected_region.last_targeted_time = time
	
	# Go to a random point in the region
	var selected_location_2d:Vector2 = MathUtils.get_random_point_in_rect(selected_region.area)
	var selected_location:Vector3 = Vector3(selected_location_2d.x, current_pos.y, selected_location_2d.y)
	
	if not heading_bias_raw:
		return selected_location
		
	# Bias in direction of heading_bias
	var to_location:Vector3 = selected_location - current_pos
	var distance:float = to_location.length()
	
	var selected_heading:Vector3 = to_location / maxf(distance, 0.001)
	var final_heading:Vector3 = _bias_heading(selected_heading, heading_bias_raw)
	
	# Keep same distance
	var target_location:Vector3 = final_heading * distance
	
	return target_location
	
#endregion

#region Randomized Move Target
func _get_randomized_move_target(unit:Unit, heading_bias_raw:Vector3) -> Vector3:
	var pos:Vector3 = unit.global_position
	var heading:Vector3 = unit.global_forward
	
	var heading_deviation_deg:float = randf_range(heading_variation_degrees.x, heading_variation_degrees.y)
	var new_heading:Vector3 = heading.rotated(Vector3.UP, deg_to_rad(heading_deviation_deg))
	
	if heading_bias_raw:
		new_heading = _bias_heading(new_heading, heading_bias_raw)
		
	var result:PackedVector3Array
	result.resize(1)
	
	var unit_attributes:TeamAssetAttributes = unit.attributes
	var move_radius:Vector2 = unit_attributes.explore_range if unit_attributes else default_move_radius
	
	# If fail, try different orientations and reduce distance variance
	for i in MAX_ATTEMPTS:
		var max_distance:float = maxf(move_radius.x, move_radius.y * (1.0 - 0.2 * i))
		if i > 0:
			new_heading = new_heading.rotated(Vector3.UP, PI / i * (1.0 if i % 2 == 0 else -1.0))
		if _try_potential_target(pos, new_heading, move_radius.x, max_distance, result):
			return result[0]
	push_warning("%s: %s - Could not find viable position after %d attempts from %s" % \
		[name, unit.name, MAX_ATTEMPTS, pos])		
	return pos

#endregion

func _bias_heading(heading:Vector3, heading_bias_raw:Vector3) -> Vector3:
	# Lerp between heading_bias and new_heading based on the heading weight (length)
	# Use slerp because we are working with direction vectors
	var bias_size:float = heading_bias_raw.length()
	var heading_bias:Vector3 = heading_bias_raw / maxf(0.001, bias_size)
	return heading.slerp(heading_bias, minf(bias_size, 1.0))
		
func _try_potential_target(pos:Vector3, heading:Vector3, min_distance:float, max_distance:float, out_result:PackedVector3Array) -> bool:
	var distance:float = randf_range(min_distance, max_distance)
	var target_pos:Vector3 = pos + heading * distance
	
	if not world_boundaries_checker or world_boundaries_checker.is_within_bounds(target_pos):
		out_result[0] = target_pos
		return true
	return false		
