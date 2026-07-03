extends Node

var _match:Match
var _match_team:MatchTeam

var _min_scrap_no_commmand_center:int

@export_range(0, 1.0, 0.01)
var army_strength_fraction_timer_trigger:float = 0.7

@export_range(0.0, 1.0, 0.01)
var army_strength_fraction_defeat_trigger:float = 0.1

@export
var time_to_rebuild_command_center:float = 120.0

var _match_end_timer:Timer

func _ready() -> void:
	_match = get_tree().get_first_node_in_group(Groups.Match) as Match
	assert(_match)
	
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	assert(_match_team)
	if not _match_team:
		push_error("%s: Not in tree with MatchTeam parent" % name)
		queue_free()
		return
		
	SignalBus.match_ready.connect(_on_match_ready.unbind(1), ConnectFlags.CONNECT_ONE_SHOT)

func _on_match_ready() -> void:
	# Determine cost for command center
	var command_center_cost: ConstructionResource = _match_team.team_resources.get_construction_resource(ConstructionResource.Type.CommandCenter)
	if command_center_cost:
		_min_scrap_no_commmand_center = command_center_cost.cost
	else:
		push_error("%s: Could not find team resource cost for CommandCenter" % name)
			
	_match_team.units_changed.connect(_on_conditions_changed)
	_match_team.buildings_changed.connect(_on_conditions_changed)
	_match_team.structures_changed.connect(_on_conditions_changed)
		
func _on_conditions_changed() -> void:
	if _has_command_center():
		_remove_elimination_timer()
		return
	
	# If no available control points or owned command center then trigger failure
	if not _owned_or_open_control_points():
		print_debug("%s: MatchTeam %s has been eliminated due to having no command centers and enemy controls all control points" % [name, _match_team.name])
		_eliminate_team()
		return
		
	# Check if above strength threshold
	var strength_fraction:float = _compute_army_strength_fraction()
	if strength_fraction > army_strength_fraction_timer_trigger:
		_remove_elimination_timer()
		return
		
	if strength_fraction < army_strength_fraction_defeat_trigger:
		print_debug("%s: MatchTeam %s has been eliminated due to having no command centers and army strength is %.3f of max strength" % [name, _match_team.name, strength_fraction])
		_eliminate_team()
		return
	
	# See if have enough resources to rebuild command center in a reasonable amount of time
	if _match_team.resources.scrap.count < _min_scrap_no_commmand_center or not _open_scrap_field_exists():
		print_debug("%s: MatchTeam %s has been eliminated due to not having ability to rebuild command center; army strength=%.3f" % [name, _match_team.name, strength_fraction])
		_eliminate_team()
		return
		
	_add_team_elimination_timer()
	
func _has_command_center() -> bool:
	for building in _match_team.buildings:
		if building is CommandCenter:
			return true
	return false

func _eliminate_team() -> void:
	if not _match_team.active:
		return
		
	_remove_elimination_timer()
		
	@warning_ignore("missing_await")
	_match_team.eliminate()
	
func _add_team_elimination_timer() -> void:
	if _match_end_timer:
		return
		
	_match_end_timer = Timer.new()
	_match_end_timer.name = "TeamEliminationTimer"
	_match_end_timer.autostart = true
	_match_end_timer.one_shot = true
	_match_end_timer.timeout.connect(_on_elimination_timer_timeout)
	
	print_debug("%s: MatchTeam %s elimination timer of %.1fs started" % [name, _match_team.name, time_to_rebuild_command_center])

	add_child(_match_end_timer)

func _on_elimination_timer_timeout() -> void:
	print_debug("%s: MatchTeam %s has been eliminated due being unable to rebuild command center in %.1fs" % [name, _match_team.name, time_to_rebuild_command_center])
	_eliminate_team()
	
func _remove_elimination_timer() -> void:
	if not _match_end_timer:
		return
		
	_match_end_timer.queue_free()
	_match_end_timer = null
	
	print_debug("%s: MatchTeam %s elimination timer removed" % [name, _match_team.name])

		
func _open_scrap_field_exists() -> bool:
	for node in get_tree().get_nodes_in_group(Groups.ScrapField):
		var scrap_field:ScrapField = node as ScrapField
		if scrap_field and scrap_field.open:
			return true
	return false

func _owned_or_open_control_points() -> bool:
	for node in get_tree().get_nodes_in_group(Groups.ControlPoint):
		var control_point:ControlPoint = node as ControlPoint
		if control_point.neutral or control_point.owned_team == _match_team.team: 
			return true
	return false

func _compute_army_strength_fraction() -> float:
	var max_opponent_strength:float = 0.1
	var team_strength:float = _compute_strength(_match_team)
	
	for opponent in _match.active_teams:
		if opponent == _match_team:
			continue
		max_opponent_strength = maxf(_compute_strength(opponent), max_opponent_strength)

	return team_strength / max_opponent_strength
	
static func _compute_strength(match_team:MatchTeam) -> float:
	var strength:float = 0.0
	for unit in match_team.units:
		var attributes := unit.attributes
		if attributes:
			strength += attributes.strength
	return strength
