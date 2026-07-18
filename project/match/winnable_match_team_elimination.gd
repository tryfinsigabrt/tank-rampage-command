extends Node

var _match:Match
var _match_team:MatchTeam

@export
var condition:String = "Destroy all enemy command centers and either capture all control points or defeat all enemy units."

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
	_match_team.units_changed.connect(_on_conditions_changed)
	_match_team.buildings_changed.connect(_on_conditions_changed)
		
func _on_conditions_changed() -> void:
	# Must destroy all command centers
	if _has_active_command_center():
		return
	
	# If no available control points then trigger failure
	if not _owned_or_open_control_points():
		print_debug("%s: MatchTeam %s has been eliminated due to having no command centers and enemy controls all control points" % [name, _match_team.name])
		_eliminate_team()
		return
		
	# Check if no remaining units
	if _match_team.units.is_empty():
		print_debug("%s: MatchTeam %s has been eliminated due to having no command centers and no units" % [name, _match_team.name])
		_eliminate_team()
		return
	
func _has_active_command_center() -> bool:
	for building in _match_team.buildings:
		var command_center:CommandCenter = building as CommandCenter
		if not command_center:
			continue
		# Make sure actively mining
		var mining_component := MiningComponent.get_component(command_center)
		if mining_component and mining_component.mining:
			return true
	return false

func _eliminate_team() -> void:
	if not _match_team.active:
		return
				
	@warning_ignore("missing_await")
	_match_team.eliminate()

func _owned_or_open_control_points() -> bool:
	for node in get_tree().get_nodes_in_group(Groups.ControlPoint):
		var control_point:ControlPoint = node as ControlPoint
		if control_point.neutral or control_point.owned_team == _match_team.team: 
			return true
	return false
