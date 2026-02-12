class_name WorldBoundariesChecker extends Node

var _world_boundaries:WorldBoundaries

var world_boundaries:WorldBoundaries:
	get:
		if _world_boundaries:
			return _world_boundaries
		_world_boundaries = get_tree().get_first_node_in_group(Groups.WorldBoundaries) as WorldBoundaries
		if not _world_boundaries:
			push_warning("%s: No WorldBoundaries node available in scene tree" % name)
		return _world_boundaries
		
func is_within_bounds(position:Vector3) -> bool:
	var bounds := world_boundaries
	return bounds.contains_point(position) if bounds else true
