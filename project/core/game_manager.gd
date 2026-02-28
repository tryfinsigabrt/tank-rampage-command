extends Node

@onready var game_timer: GameTimer = %GameTimer
@onready var scene_manager: SceneManager = %SceneManager

var fog_of_war:bool

func _ready() -> void:
	var node:FogOfWar = get_tree().get_first_node_in_group(Groups.FogOfWar) as FogOfWar
	if node and node.enable:
		fog_of_war = true
