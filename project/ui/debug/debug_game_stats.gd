extends VBoxContainer

@onready var game_timer: Label = $GameTimer
@onready var team_stats: Label = $TeamStats

var _team_stat_lines:PackedStringArray

func _tick() -> void:
	if not is_visible_in_tree():
		return
		
	game_timer.text = "Time: %.1fs" % GameManager.game_timer.time_seconds
	
	var game_match:Match = get_tree().get_first_node_in_group(Groups.Match)
	if not game_match:
		return
	
	_team_stat_lines.clear()
	
	for team in game_match.teams:
		_team_stat_lines.push_back("TEAM %d: u=%d b=%d" % [team.team, team.units.size(), team.buildings.size()])
	
	team_stats.text = "\n".join(_team_stat_lines)
