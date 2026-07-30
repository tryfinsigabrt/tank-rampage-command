extends Node3D

@onready var mesh: MeshInstance3D = $Mesh

@export
var wait_time:float = 0.1

@export
var outline_materials:Array[Material]

func _ready() -> void:
	for material in outline_materials:
		MaterialUtils.set_overlay_material(mesh, material, null, true)
		await get_tree().create_timer(wait_time).timeout
