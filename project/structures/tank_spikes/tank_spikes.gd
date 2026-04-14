class_name TankSpikes extends DefensiveStructure

@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI
	
func _do_update_render(in_visible:bool) -> void:
	visual_root.visible = in_visible
	ui.visible = in_visible

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass
