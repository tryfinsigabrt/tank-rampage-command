class_name MatchProgressNotifications extends Node

const notifications_scene:PackedScene = preload("uid://crooxytfm2w0g")

@export
var winner_notification_delay_seconds:float = 2.0

func _ready() -> void:
	SignalBus.match_ready.connect(_on_match_ready)
	SignalBus.match_team_eliminated.connect(_on_team_eliminated)
	SignalBus.match_ended.connect(_on_match_complete)
	
func _on_match_ready(_match_object:Match) -> void:
	_display_message("Start!")
	
func _on_team_eliminated(match_team:MatchTeam) -> void:
	_display_message("%s eliminated" % match_team.name)
	
func _on_match_complete(match_object:Match) -> void:
	var winning_team:MatchTeam = match_object.winner
	if winning_team:
		var message:String = "%s wins!" % winning_team.name
		await get_tree().create_timer(winner_notification_delay_seconds).timeout
		_display_message(message)
	
func _display_message(message:String) -> void:
	var scene:ToastNotification = notifications_scene.instantiate()
	scene.message = message
	add_child(scene)
