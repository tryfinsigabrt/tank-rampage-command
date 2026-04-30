class_name SceneSpawningHitVfx extends HitVfx

@export
var vfx_scene:PackedScene

@export
var scene_properties:Dictionary[StringName, Variant]

func _ready() -> void:
	assert(vfx_scene, "Vfx Scene not set!")

func start(params:DamageParameters) -> void:
	if not vfx_scene:
		return
	
	var instance:Node = vfx_scene.instantiate()
	
	# Set extra properties on instance before adding to scene
	for key in scene_properties:
		if key in instance:
			instance.set(key, scene_properties[key])
			
	add_child(instance)
	
	if instance is Node3D:
		# Need to set position after putting node in tree
		instance.global_position = params.contact_point
