class_name Visibility

class Layers:
	const team_1:int = 1 << 16
	const team_2:int = 1 << 17
	# reserving 18 and 19 if we have 4 total teams
	
	const team_masks:Dictionary[int,int] = {
		1 : Layers.team_1,
		2 : Layers.team_2,
	}
	
	const all_teams:int = team_1 | team_2

static func enemy_team_mask(team:int) -> int:
	var team_mask:int = Layers.team_masks.get(team, 0)
	if team_mask == 0:
		push_warning("Collisions: Invalid team=%d" % team)
	return Layers.all_teams ^ team_mask
	
static func apply_team_collision_layer(root: Node, team: int, recursive:bool = true) -> void:
	if not is_instance_valid(root):
		return
		
	var team_mask:int = Layers.team_masks.get(team, -1) if team > 0 else 0
	if team_mask < 0:
		push_warning("Visibility: Invalid team=%d; root=%s" % [team, StringUtils.safe_name(root)])
		return
	
	var nodes:Array[Node] = [root]
	while nodes:
		var node: Node = nodes.pop_back()
		if node is VisualInstance3D:
			node.layers = MathUtils.update_mask(node.layers, Layers.all_teams, team_mask)
			if not recursive:
				return
		for child in node.get_children():
			nodes.push_back(child)
