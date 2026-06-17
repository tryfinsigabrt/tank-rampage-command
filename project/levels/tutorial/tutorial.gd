extends Node3D

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
Command the selected units to move by right clicking.",

	"Order all your units to advance up the road and take control of a [b]Control point[/b].\n
Control points increase your personnel capacity."
	]

var msg_index := -1


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
