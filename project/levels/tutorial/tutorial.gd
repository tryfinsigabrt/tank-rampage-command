extends Node3D

const AI_MARINE_RESOURCE: ConstructionResource = preload("res://conf/costs/ai/ai_marine_cost.tres")
const AI_TANK_RESOURCE: ConstructionResource = preload("res://conf/costs/ai/ai_tank_cost.tres")
const ENEMY_TEAM_ID := 2

const MESSAGES := [
	"[b]Welcome to the Tank Rampage Command tutorial[/b]\nClick \"Next\" to continue.", 
	
	"Camera controls:\n- Move the mouse to the screen edge or use the arrow keys to pan.\
	\n- Hold middle mouse and drag to pan freely.\
	\n- Press [b]Q[/b] or [b]E[/b] to rotate.\
	\n- Use the mouse wheel or [b]+[/b] / [b]-[/b] to zoom.",
	
	"Use the [b]Construction panel[/b] in the bottom right to build a [b]Barracks[/b] and a [b]Factory[/b].\n\n\
When you left click on a building icon, choose where you want to place it and left click again to start building\n
Buildings cost [b]Scrap[/b] to build, you can see how much scrap you have in the [b]Resource panel[/b] in the top right corner",
	
	  
	"Barracks can train [b]Marines[/b], these are your close range infantry units.\n\
Factory can build [b]Tanks[/b], a versitile medium range and fast armoured unit.\n\
You can also build [b]Artilery[/b] units in a factory, a slow moving but devastating long range unit.",
	
	"Units cost scrap and require [b]Personnel[/b] capacity available.\n
You can train new units by clicking on the barracks or the factory, then clicking on the unit icon to start training.\n\n
Train up enough units to reach the current peronnel capacity.",

	"To select a unit left click on it, or left click and drag to select multiple units.\n
Command the selected units to move by right clicking. \n\n
Selected units appear in the bottom left next to the minimap, you can see their health bars and \
different commands you can issue them on the right.",

	"Order all your units to advance up the road and take control of a [b]Control point[/b].\n
Control points increase your personnel capacity which allows you to build more units.",

	"There is a [b]Scrap field[/b] next to the control point, build a [b]Command Center[/b] on top of it.\n
The command center will extract Scrap from the scrap field which you can use to build more units and buildings.",

	"The enemy base is close by, advance further along the road with your units, engage the enemy combatants \
and destroy their base to complete the tutorial."
	]

var msg_index := -1
var _enemy_reinforcements_spawned := false


func _ready() -> void:
	SignalBus.on_player_message_next_clicked.connect(_on_player_message_next_clicked)
	_advance_tutorial()


func _exit_tree() -> void:
	if SignalBus.on_player_message_next_clicked.is_connected(_on_player_message_next_clicked):
		SignalBus.on_player_message_next_clicked.disconnect(_on_player_message_next_clicked)


func _on_player_message_next_clicked() -> void:
	_advance_tutorial()
	

func _advance_tutorial() -> void:
	msg_index += 1
	
	if msg_index < MESSAGES.size():
		SignalBus.on_player_message_requested.emit(MESSAGES[msg_index])
		if msg_index == MESSAGES.size() - 1:
			_spawn_enemy_reinforcements()
	else:
		SignalBus.on_player_message_cleared.emit()

func _spawn_enemy_reinforcements() -> void:
	if _enemy_reinforcements_spawned:
		return

	var enemy_team := GameManager.find_match_team_by_id(ENEMY_TEAM_ID)
	var enemy_base := get_node_or_null("World/Match/EnemyTeams/EnemyTeam/EnemyTeamDirector/CommandCenter") as Node3D
	if enemy_team == null or enemy_base == null:
		return

	_enemy_reinforcements_spawned = true

	var marine_offsets := [
		Vector3(-18.0, 0.0, 20.0),
		Vector3(0.0, 0.0, 24.0),
		Vector3(18.0, 0.0, 20.0),
	]
	for offset in marine_offsets:
		_spawn_enemy_unit(enemy_team, AI_MARINE_RESOURCE, enemy_base.global_position + offset)

	var tank_offsets := [
		Vector3(-20.0, 0.0, -18.0),
		Vector3(20.0, 0.0, -18.0),
	]
	for offset in tank_offsets:
		_spawn_enemy_unit(enemy_team, AI_TANK_RESOURCE, enemy_base.global_position + offset)

func _spawn_enemy_unit(enemy_team: MatchTeam, construction_resource: ConstructionResource, spawn_position: Vector3) -> void:
	if construction_resource == null or construction_resource.team_asset == null:
		return

	var unit := construction_resource.team_asset.instantiate() as Node3D
	if unit == null:
		return

	if construction_resource.visual_overrides and "team_resource" in unit:
		unit.team_resource = construction_resource.visual_overrides
	construction_resource.assign_to(unit)

	enemy_team.assign_to_team(unit)
	unit.global_position = spawn_position
