extends Node

const MAIN_MENU_SCENE:PackedScene = preload("uid://crt8b4t030yrm")
const GAME_SCENE:PackedScene = preload("uid://y2gjgrbqtl7n")

signal scene_changed(new_scene:Node)

func main_menu() -> void:
	await switch_scene(MAIN_MENU_SCENE)

func new_game() -> void:
	await switch_scene(GAME_SCENE)
	
func pause_game(paused:bool) -> void:
	get_tree().paused = paused
	SignalBus.pause_game.emit(paused)
	
func switch_scene(scene:PackedScene, configurator:Callable = Callable()) -> void:
	await _switch_scene(func()->Node: 
		var instantiated:Node = scene.instantiate()
		if configurator:
			configurator.call(instantiated)
		return instantiated
	)
	
func switch_scene_file(scene_file:String, configurator:Callable = Callable()) -> void:
	await _switch_scene(func()->Node: 
		var scene:PackedScene = load(scene_file)
		var instantiated:Node = scene.instantiate()
		if configurator:
			configurator.call(instantiated)
		return instantiated
	)

func _switch_scene(scene_loader:Callable) -> void:    
	var root := get_tree().root
	var root_current_scene := root.get_child(root.get_child_count() - 1)
	print_debug("%s: Freeing current root scene=%s" % [name, root_current_scene.scene_file_path])
	root_current_scene.queue_free()

	if OS.is_debug_build():
		await get_tree().process_frame
		print_debug("**********BEGIN ORPHAN NODES**********")
		print_orphan_nodes()		
		print_debug("**********END ORPHAN NODES**********")
	
	var current_scene:Node = scene_loader.call()
	
	# Somehow get_tree().current_scene is null inside _ready of the loaded scene
	# even if we do get_tree().current_scene = current_scene before
	# So instead set the current_scene on SceneManager and have it manage the current_scene rather than the tree root
	# So replaced all references to this
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	get_tree().paused = false

	scene_changed.emit(current_scene)
