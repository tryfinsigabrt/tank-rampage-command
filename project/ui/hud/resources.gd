extends VBoxContainer

@onready var personnel_value: Label = %PersonnelValue
@onready var scrap_value: Label = %ScrapValue

var _match_team:MatchTeam

func _ready() -> void:
	var player:Player = get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		push_warning("%s: Could not find player - resources will display 0's" % name)
		_default_values()
		return
	_match_team = player.player_team
	if not _match_team:
		push_warning("%s: MatchTeam not assigned to player node %s - resources will display 0's" % [name, player.name])
		_default_values()
		return
	_connect_signals.call_deferred()
	
func _connect_signals() -> void:
	var team_resources := _match_team.resources
	
	# Set initial values and then bind signals
	var pers := team_resources.personnel
	var scrap := team_resources.scrap
	
	_set_personnel_value(pers)
	_set_scrap_value(scrap)
	
	var on_pers_changed:Callable = _set_personnel_value.bind(pers).unbind(2)
	pers.count_changed.connect(on_pers_changed)
	pers.cap_changed.connect(on_pers_changed)

	var on_scrap_changed:Callable = _set_scrap_value.bind(scrap).unbind(2)
	scrap.count_changed.connect(on_scrap_changed)
	scrap.cap_changed.connect(on_scrap_changed)
	
func _default_values() -> void:
	personnel_value.text = "0 / 0"
	scrap_value.text = "0"

func _set_scrap_value(scrap:ScrapResource) -> void:
	scrap_value.text = str(scrap.count)

func _set_personnel_value(pers:PersonnelResource) -> void:
	personnel_value.text = "%d / %d" % [pers.count, pers.cap]
