class_name Precompilation3D extends Node3D

@onready var container: Node3D = %Scenes

#region Signals
signal started(total_count:int)
signal progress_changed(progress:float, count:int)
signal completed
#endregion

# These should already be excluded from packaged game but also doing locally to avoid
# unnecessary deep traversals
@export 
var excluded_dirs:PackedStringArray = [
	"/addons/",
	"/demo/",
	"/build/",
	"/examples/",
	"/test/"
]

func run() -> void:
	if not visible: 
		show()
	await get_tree().process_frame

	var start:int = Time.get_ticks_usec()
	await _precompile_scenes()
	var end:int = Time.get_ticks_usec()
	
	print_debug("%s: Precompilation completed in %.1fms" % [name, (end - start) / 1000.0])
	
	completed.emit()

func _precompile_scenes() -> void:
	var scenes:Array[PackedScene] = _get_tagged_scenes()
	
	started.emit(scenes.size())
	
	for i in scenes.size():
		var scene := scenes[i]
		# Could process in batches since task returns a signal that can later be awaited
		# Though the compilation process is going to be serial anyways
		await PrecompileTask.new(scene, container).run()
		
		var completed_fraction:float = float(i + 1) / scenes.size()
		progress_changed.emit(completed_fraction, 1)

func _get_tagged_scenes() -> Array[PackedScene]:
	var tagged_scenes:Array[PackedScene]
	
	var all_scene_files:PackedStringArray = _get_all_scene_files()
	print_debug("%s: Discovered %d scene files" % [name, all_scene_files.size()])
	
	for scene_file in all_scene_files:
		var scene:PackedScene = ResourceLoader.load(scene_file, "PackedScene") as PackedScene
		if not scene:
			push_warning("%s: Could not load PackedScene from resource path %s" % [name, scene_file])
			continue
		if Groups.scene_has_group(scene, Groups.Precompilation, true):
			tagged_scenes.push_back(scene)
	
	print_debug("%s: Found %d scenes tagged with %s" % [name, tagged_scenes.size(), Groups.Precompilation])	
	return tagged_scenes
		
func _get_all_scene_files() -> PackedStringArray:
	var scene_files:PackedStringArray
	var stack:Array[String]
	
	stack.push_back("res://")
	
	while stack:
		var dir:String = stack.pop_back()
		var dir_resources: PackedStringArray = ResourceLoader.list_directory(dir)
		for file in dir_resources:
			if file.ends_with(".tscn"):
				var full_path := dir + file
				scene_files.push_back(full_path)
			# Exclude dot directories like .godot and .assets by default - these won't be in the packaged game
			elif file.ends_with("/") and not file.begins_with("."):
				var full_path := dir + file
				# Make sure not in exclusion list
				var include:bool = true
				for exclusion in excluded_dirs:
					if full_path.contains(exclusion):
						include = false
						break
				if include:
					stack.push_back(full_path)
	return scene_files
