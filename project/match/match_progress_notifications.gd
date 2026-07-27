class_name MatchProgressNotifications extends Node

const notifications_scene:PackedScene = preload("uid://crooxytfm2w0g")

@export
var winner_notification_delay_seconds:float = 2.0

@export
var show_match_start:bool = true

@export
var show_team_eliminated:bool = true

@export
var show_team_wins:bool = true

const MATCH_PROGRESS_NOTIFICATION_SCALE_WORDS:Curve = preload("uid://qo8aqo1qrec2")

func _ready() -> void:
	if show_match_start:
		SignalBus.match_ready.connect(_on_match_ready)
		
	if show_team_eliminated:
		SignalBus.match_team_eliminated.connect(_on_team_eliminated)
		
	if show_team_wins:
		SignalBus.match_ended.connect(_on_match_complete)
	
func _on_match_ready(match_object:Match) -> void:
	# Get all unique match win conditions
	var player_team := GameManager.get_player_team()
	
	var unique_conditions:Dictionary[String, String]
	for match_team in match_object.teams:
		if match_team == player_team:
			continue
		var condition_node := Groups.get_child_in_group(match_team, Groups.MatchTeamEliminationCondition)
		# Must define a condition variable
		if not condition_node or "condition" not in condition_node:
			continue
		
		var condition:String = condition_node.condition
		unique_conditions[condition] = condition	
		
	var message:String = "\n".join(unique_conditions.keys()) if unique_conditions else "Start!"
	_display_message(message)
	
func _on_team_eliminated(match_team:MatchTeam) -> void:
	_display_message("%s Eliminated" % match_team.team_name, true)
	
func _on_match_complete(match_object:Match) -> void:
	var winning_team:MatchTeam = match_object.winner
	if winning_team:
		var message:String = "%s Wins!" % winning_team.team_name
		await get_tree().create_timer(winner_notification_delay_seconds).timeout
		_display_message(message, true)
	
func _display_message(message:String, continue_when_paused:bool = false) -> void:
	var scene:ToastNotification = notifications_scene.instantiate()
	scene.process_mode = Node.ProcessMode.PROCESS_MODE_ALWAYS if continue_when_paused else Node.ProcessMode.PROCESS_MODE_PAUSABLE
	
	var word_count:int = message.countn(" ") + 1
	scene.time_scale = MATCH_PROGRESS_NOTIFICATION_SCALE_WORDS.sample(word_count)
	scene.message = message
	add_child(scene)
