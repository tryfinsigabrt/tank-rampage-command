class_name SceneManager extends Node

const MAIN_MENU_SCENE:PackedScene = preload("uid://crt8b4t030yrm")
const LEVEL_SELECT_MENU_SCENE:PackedScene = preload("uid://su8ucbrnrgb1")

## Called when a scene change function has been called before anything loaded or unloaded
signal scene_change_requested(new_scene_resource:String)

## Called after the new scene's ready function has run
signal scene_changed(new_scene:Node)

## Called before the existing scene is unloaded
signal scene_leaving(old_scene:Node)

## Called after the new scene is instantiated but before it is added to the tree
signal scene_entering(new_scene:Node)

@onready var _game_config_holder: GameConfigHolder = %GameConfigHolder

var paused:bool:
	get: return get_tree().paused
	
func main_menu() -> void:
	await switch_scene(MAIN_MENU_SCENE)

func level_select_menu() -> void:
	await switch_scene(LEVEL_SELECT_MENU_SCENE)

func play_now() -> void:
	await switch_scene_file(_game_config_holder.game_config.levels.pick_random())
	
func play_tutorial() -> void:
	await switch_scene_file(_game_config_holder.game_config.tutorial_level.level_resource)

func play_level(level_number:int) -> void:
	var all_levels := _game_config_holder.game_config.levels
	assert(level_number > 0 and level_number <= all_levels.size(),"%s: Invalid level number=%d" % [name, level_number])
	await switch_scene_file(all_levels[level_number - 1].level_resource)
	
func quit() -> void:
	get_tree().quit()
	
func toggle_pause() -> void:
	pause_game(not paused)
	
func pause_game(in_paused:bool) -> void:
	var currently_paused:bool = paused
	if currently_paused == in_paused:
		return
		
	get_tree().paused = in_paused
	SignalBus.on_paused.emit(in_paused)
	
func switch_scene(scene:PackedScene, configurator:Callable = Callable()) -> void:
	scene_change_requested.emit(scene.resource_path)
	
	await _switch_scene(func()->Node: 
		var instantiated:Node = scene.instantiate()
		if configurator:
			configurator.call(instantiated)
		return instantiated
	)
	
func switch_scene_file(scene_file:String, configurator:Callable = Callable()) -> void:
	scene_change_requested.emit(scene_file)
	
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
	scene_leaving.emit(root_current_scene)
	print_debug("%s: Freeing current root scene=%s" % [name, root_current_scene.scene_file_path])
	root_current_scene.queue_free()

	if OS.is_debug_build():
		await get_tree().process_frame
		print_debug("**********BEGIN ORPHAN NODES**********")
		print_orphan_nodes()		
		print_debug("**********END ORPHAN NODES**********")
	
	var current_scene:Node = scene_loader.call()
	
	scene_entering.emit(current_scene)
	# Somehow get_tree().current_scene is null inside _ready of the loaded scene
	# even if we do get_tree().current_scene = current_scene before
	# So instead set the current_scene on SceneManager and have it manage the current_scene rather than the tree root
	# So replaced all references to this
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	get_tree().paused = false

	scene_changed.emit(current_scene)
