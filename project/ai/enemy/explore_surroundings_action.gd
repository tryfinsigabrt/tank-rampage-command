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

var _cluster_creator:ClusterCircleCreator = ClusterCircleCreator.new(preferred_unit_group_proximity)
	
const FOLLOWER_UNIT_CLASSES: Array[Unit.UnitClass] = [
	Unit.UnitClass.Artillery
]

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not world_boundaries_checker:
		push_warning("%s: WorldBoundariesChecker not set - no bounds testing on move targets!" % name)
		
func tick(_actor: Node, _blackboard: Blackboard) -> int:	
	var blackboard:EnemyTeamBlackboard = _blackboard
	
	var heading_bias_dict: Dictionary[int, Vector3] = blackboard.explore_heading_bias
		
	for group in _get_unit_groups(blackboard):
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
	
func _get_unit_groups(blackboard:EnemyTeamBlackboard) -> Array[Array]:
	var available_units:Array[Unit] = _get_available_units(blackboard)
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
	
func _get_available_units(blackboard:EnemyTeamBlackboard) -> Array[Unit]:
	var candidate_units := blackboard.idle_units
	var available_units:Array[Unit]
	available_units.resize(candidate_units.size())
	
	var count:int = 0
	for i in available_units.size():
		var unit:Variant = candidate_units[i]
		# TODO: Shouldn't have to do this - the monitor should be taking care of this but it's not working properly as still 
		# encounter "previously freed" - another approach would be to convert idle_units to just PackedInt64Array
		if not is_instance_valid(unit):
			continue
		
		available_units[count] = unit
		count += 1
	available_units.resize(count)
	
	return available_units
	
func _select_move_target(unit:Unit, heading_bias:Vector3) -> Vector3:
	if LogUtils.debug:
		print_debug("%s: Select move target for unit=%s" % [name, unit.name])
	
	var target_pos:Vector3 = _get_move_target(unit, heading_bias)
	
	if heading_bias:
		unit.get_or_add_actions().move(target_pos)
	else:
		unit.get_or_add_actions().move_and_attack(target_pos)
	
	return target_pos

func _get_move_target(unit:Unit, heading_bias_raw:Vector3) -> Vector3:
	# TODO: Will switch to a region list strategy based on WorldBoundaries that divides up the map into 25x25 region blocks
	# and marks metadata such as explored, visible to bias toward the frontier and not a random walk from current position
	var pos:Vector3 = unit.global_position
	var heading:Vector3 = unit.global_forward
	
	var heading_deviation_deg:float = randf_range(heading_variation_degrees.x, heading_variation_degrees.y)
	var new_heading:Vector3 = heading.rotated(Vector3.UP, deg_to_rad(heading_deviation_deg))
	
	# Lerp between heading_bias and new_heading based on the heading weight (length)
	# Use slerp because we are working with direction vectors
	if heading_bias_raw:
		var bias_size:float = heading_bias_raw.length()
		var heading_bias:Vector3 = heading_bias_raw / maxf(0.001, bias_size)
		new_heading = new_heading.slerp(heading_bias, minf(bias_size, 1.0))
		
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
		
func _try_potential_target(pos:Vector3, heading:Vector3, min_distance:float, max_distance:float, out_result:PackedVector3Array) -> bool:
	var distance:float = randf_range(min_distance, max_distance)
	var target_pos:Vector3 = pos + heading * distance
	
	if not world_boundaries_checker or world_boundaries_checker.is_within_bounds(target_pos):
		out_result[0] = target_pos
		return true
	return false		
