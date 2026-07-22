extends VBoxContainer

@onready var team_stats: Label = $TeamStats

var _team_stat_lines:PackedStringArray

func _tick() -> void:
	if not is_visible_in_tree():
		return
			
	var game_match:Match = get_tree().get_first_node_in_group(Groups.Match)
	if not game_match:
		return
	
	_team_stat_lines.clear()
	
	for team in game_match.teams:
		var inventory:InventoryComponent = team.inventory_component
		if not inventory:
			continue
		var types := inventory.get_available_types()
		var values: PackedStringArray
		for type in types:
			var count:int = inventory.get_count(type)
			values.push_back("%s:%d" % [EnumUtils.enum_to_string(ConstructionResource.Type, type), count])
			
		_team_stat_lines.push_back("TEAM %d: %s" % [team.team, " ".join(values) if values else "NO INV"])
	
	team_stats.text = "\n".join(_team_stat_lines)
