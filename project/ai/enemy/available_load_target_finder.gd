class_name AvailableLoadTargetFinder extends Node

const BUNKER_SUPPORTED_GROUPS:PackedStringArray = [Groups.Structures.Bunker]
const TRANSPORT_SUPPORTED_GROUPS:PackedStringArray = [Groups.Units.Transport]

## Maximum angle unit can deviate along path to the target
@export
var max_angle_degrees:float = 15.0
	
func find_best_load_target_along_path(unit:Unit, target_position:Vector3, supported_groups:PackedStringArray = PackedStringArray()) -> Node3D:
	var match_team:MatchTeam = GameManager.find_match_team_by_id(unit.team)
	if not match_team:
		push_warning("%s: Could not determine match team for unit=%s" % [name, unit.name])
		return null
	
	var best_load_target:Node3D
	var best_dist_sq:float = INF
	
	var unit_pos := unit.global_position
	var target_dir:Vector3 = unit_pos.direction_to(target_position)

	for asset:Node3D in match_team:
		if asset == unit:
			continue
		
		if supported_groups and not _in_supported_group(asset, supported_groups):
			continue
			
		var unit_container:UnitContainerComponent = UnitContainerComponent.get_component(asset, false)
		if not unit_container or unit_container.is_full or not unit_container.supports_unit(unit):
			continue
		
		# Check heading and then see if best distance
		var container_pos := asset.global_position
		var to_container:Vector3 = unit_pos.direction_to(container_pos)

		var angle_to_asset:float = target_dir.angle_to(to_container)
		if angle_to_asset > max_angle_degrees:
			continue
		
		var dist_sq:float = unit_pos.distance_squared_to(container_pos)
		if dist_sq < best_dist_sq:
			best_load_target = asset
			best_dist_sq = dist_sq
		
	return best_load_target

static func _in_supported_group(node:Node, supported_groups:PackedStringArray) -> bool:
	for group in supported_groups:
		if node.is_in_group(group):
			return true
	return false
