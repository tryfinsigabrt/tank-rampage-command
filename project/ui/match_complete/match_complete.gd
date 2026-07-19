extends MarginContainer

const team_row_scene:PackedScene = preload("uid://bv7kr6iu0prnx")

@onready var match_teams_container: GridContainer = %MatchTeams
@onready var buttons_container: HBoxContainer = %Buttons
@onready var header: Label = %TitleHeader
@onready var game_time_label: Label = %GameTimeLabel

func _ready() -> void:
	var match_obj:Match = get_tree().get_first_node_in_group(Groups.Match) as Match
	if not match_obj:
		push_error("%s: No Match node found in tree!" % name)
		return
	
	var winner:MatchTeam = match_obj.winner
	if not winner:
		push_error("%s: Displayed before there was a winner!" % name)
	elif winner == match_obj.player_team:
		header.text = "Victory!"
	else:
		header.text = "Defeat!"
	
	game_time_label.text = "Time: %s" % _format_time(match_obj.time)
	
	var teams := match_obj.teams
	if winner:
		# Swap winner to the front
		var winner_index:int = teams.find(winner)
		if winner_index > 0:
			var previous_first:MatchTeam = teams[0]
			teams[0] = teams[winner_index]
			teams[winner_index] = previous_first
		
	for team in teams:
		var team_row:MatchCompleteTeamRow = team_row_scene.instantiate()
		team_row.match_team = team
		match_teams_container.add_child(team_row)
		# Move children of the match teams container directly into the grid container
		for child in team_row.get_children():
			child.reparent(match_teams_container)
		team_row.queue_free()
	
	await _end_gameplay()		

func _end_gameplay() -> void:
	# Remove pause menu so it doesn't show on top of the results
	var pause_menu_scene:Node = get_tree().get_first_node_in_group(Groups.PauseMenu)
	if pause_menu_scene:
		pause_menu_scene.queue_free()
		await get_tree().process_frame
		
	# Disable unpause and force game paused
	pause()
	SignalBus.on_paused.connect(_on_paused)
	
func _on_paused(is_paused:bool) -> void:
	if not is_paused:
		pause()
			
static func pause() -> void:
	GameManager.scene_manager.pause_game(true)
	
func _on_restart_pressed() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(buttons_container, 20.0)
	
	@warning_ignore("missing_await")
	GameManager.scene_manager.restart_scene()

@warning_ignore("missing_await")
func _on_main_menu_pressed() -> void:
	@warning_ignore("missing_await")
	UIUtils.disable_all_buttons(buttons_container, 20.0)

	@warning_ignore("missing_await")
	GameManager.scene_manager.main_menu()

static func _format_time(time_in_seconds: float) -> String:
	# Convert total seconds to integers
	var minutes: int = int(time_in_seconds / 60)
	var seconds: int = int(time_in_seconds) % 60
	
	# %02d formats the integer to always take up at least 2 digits, padding with '0'
	return "%02d:%02d" % [minutes, seconds]
