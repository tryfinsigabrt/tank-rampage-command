class_name CommandCenter extends Building

var _personnel:PersonnelResource

func _ready() -> void:
	super._ready()
	
	await _initialize_personnel()
	
func _initialize_personnel() -> void:
	if team_component:
		var match_team:MatchTeam = GameManager.find_match_team_by_id(team_component.team)
		if match_team:
			await match_team.wait_for_ready()
			_personnel = match_team.resources.personnel
			_increase_personnel_cap()
		else:
			push_error("%s: Could not find match team %d - cannot assign personnel cap increase" % [name, team_component.team])

func _increase_personnel_cap() -> void:
	if _personnel:
		_personnel.cap += _personnel.control_point_cap_bonus
	
func _decrease_personnel_cap() -> void:
	if _personnel:
		_personnel.cap -= _personnel.control_point_cap_bonus
			
func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	_decrease_personnel_cap()
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass
