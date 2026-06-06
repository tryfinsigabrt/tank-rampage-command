class_name BunkerStructure extends DefensiveStructure

@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI
@onready var _unit_container_component: UnitContainerComponent = %UnitContainerComponent

func _do_update_render(in_visible:bool) -> void:
	visual_root.visible = in_visible
	ui.visible = in_visible

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	_remove_all_units()
	
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass

func _remove_all_units() -> void:
	_unit_container_component.remove_all_units()
		
func _on_unit_added(unit: Unit) -> void:
	_add_to_bunker_defense(unit)

func _add_to_bunker_defense(unit: Unit) -> void:
	unit.hide()
	unit.get_or_add_actions().hold()
	
func _remove_from_bunker_defense(unit: Unit) -> void:
	unit.show()
	unit.get_or_add_actions().stop()
	
func _on_unit_removed(unit: Unit) -> void:
	_remove_from_bunker_defense(unit)
	# TODO: Place outside bunker like when the manfacturing component finds an available spot for unit to spawn
