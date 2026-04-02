extends Node3D

#@export
#var scene:PackedScene

@onready var render_to_texture: SubViewport = %RenderToTexture
@onready var icon_root: Node3D = %IconRoot

func _ready() -> void:
	#if not scene:
		#push_warning("%s: No scene" % name)
		#return
		#
	#var node: Node3D = scene.instantiate() as Node3D
	#if not node:
		#push_warning("%s: Instantiated scene=%s is not a Node3D!" % [name, scene.resource_path])
		#return
	
	var cameras: Array[Node] = Groups.get_children_with_type(self, Camera3D)
	var active_camera:Camera3D = cameras.filter(func(cam:Camera3D) -> bool: return cam.is_visible_in_tree()).front()
	active_camera.make_current()
	await get_tree().process_frame
	
	var render_camera: Camera3D = active_camera.duplicate()
	render_to_texture.add_child(render_camera)
	
	#icon_root.add_child(node)
	
	var active_node: Node3D = icon_root.get_children().filter(func(node:Node) -> bool: return node is Node3D and node.is_visible_in_tree()).front()
	if not active_node:
		push_warning("%s: No visible node - no screenshot taken" % name)
		return
	
	_export_screenshot.call_deferred(active_node)

func _export_screenshot(active_node:Node3D) -> void:
	await RenderingServer.frame_post_draw
	
	var viewport_texture := render_to_texture.get_texture()
	# Convert the texture to an Image
	var image := viewport_texture.get_image()
	
	# Save the image to the local filesystem
	#var scene_resource: String = scene.resource_path
	#var scene_file: String = scene_resource.get_file()
	#var ext: String = scene_resource.get_extension()
	#var scene_name := scene_file.replace("." + ext, "")
	var scene_name: String = active_node.name
	
	var save_file_name := "%s.png" % scene_name
	var save_file := "user://%s" % save_file_name
	var save_file_log := "%s/%s" % [OS.get_user_data_dir(), save_file_name]
	
	var error := image.save_png(save_file)
	
	if error == OK:
		print("Image saved successfully to: ", save_file_log)
	else:
		push_error("Failed to save image to %s - Error code: " % [save_file_log, error])
