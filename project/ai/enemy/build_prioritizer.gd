class_name BuildPrioritizer extends Node

@onready var blackboard: EnemyTeamBlackboard = %Blackboard
@onready var decision_loop_timer: Timer = $DecisionLoopTimer
@onready var build_utility_calculator: BuildUtilityCalculator = $BuildUtilityCalculator

var _team_resources:TeamResources 
var _match_team:MatchTeam
var _building:bool

func _ready() -> void:
	var match_team:MatchTeam = await blackboard.match_team_set
	if not match_team:
		return
		
	if not match_team.is_match_ready:
		await match_team.match_team_ready
	
	_match_team = match_team
	_team_resources = match_team.resources
	_team_resources.scrap.count_changed.connect(_on_scrap_changed)
	_team_resources.personnel.cap_changed.connect(_on_personnel_cap_changed)
	_team_resources.personnel.count_changed.connect(_on_personnel_count_changed)
	
	build_utility_calculator.match_team = match_team

func _can_build_units() -> bool:
	return _team_resources.personnel.remaining and _team_resources.scrap.count > 0
func _can_build_buildings() -> bool:
	return _team_resources.scrap.count > 0
	
func _on_scrap_changed(_prev_scrap:int, new_scrap:int) -> void:
	if new_scrap > 0:
		_on_resources_available()
	else:
		decision_loop_timer.stop()
	
func _on_personnel_cap_changed(_prev_cap:int, _new_cap:int) -> void:
	if _can_build_units():
		_on_resources_available()
	
func _on_personnel_count_changed(_prev_value:int, _new_value:int) -> void:
	if _can_build_units():
		_on_resources_available()

func _on_resources_available() -> void:
	if _building or not is_inside_tree():
		return
		
	_building = true
	var available_personnel:int = _team_resources.personnel.remaining
	var available_scrap:int = _team_resources.scrap.count
	
	if LogUtils.debug:
		print_debug("%s: Resources Available: Personnel:%d, Scrap:%d" % [name, available_personnel, available_scrap])
	
	build_utility_calculator.refresh()
	
	var build_count:int = 0
	while build_utility_calculator.next_build():
		build_count += 1
	
	if LogUtils.debug:	
		print_debug("%s: Queued %d build commands" % [name, build_count])
		
	decision_loop_timer.start()
	_building = false
