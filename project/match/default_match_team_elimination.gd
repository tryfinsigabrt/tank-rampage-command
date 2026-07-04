## Default match team elimination condition where a team is eliminated if they have no more units or buildings
## Used as a placeholder for legacy reasons
class_name DefaultMatchTeamElimination extends Node

var _match_team:MatchTeam

func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	assert(_match_team)
	if not _match_team:
		push_error("%s: Not in tree with MatchTeam parent" % name)
		queue_free()
		return
		
	_match_team.units_changed.connect(_on_conditions_changed)
	_match_team.buildings_changed.connect(_on_conditions_changed)
	
func _on_conditions_changed() -> void:
	if _match_team.unit_count == 0 and _match_team.building_count == 0 and _match_team.active:
		print_debug("%s: MatchTeam %s has been eliminated due to all units and buildings being destroyed" % [name, _match_team.name])
		
		@warning_ignore("missing_await")
		_match_team.eliminate()
