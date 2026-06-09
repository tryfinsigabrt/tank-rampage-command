class_name UnitContainerActions extends Node

@export
var selection_manager:SelectionManager


func _unhandled_input(event: InputEvent) -> void:
	if not selection_manager or not selection_manager.any_structures_same_team:
		return
		
	if event.is_action_pressed(&"bunker_unload_all"):
		if unload_all_units():
			_consume_input()

func unload_all_units() -> bool:
	var removed:bool = false
	for container in get_unit_container_selections():
		if container.any:
			container.remove_all_units()
			removed = true
	return removed
		
func get_unit_container_selections() -> Array[UnitContainerComponent]:
	var components:Array[UnitContainerComponent]
	for structure in selection_manager.get_selected_structures_on_team():
		var comp:UnitContainerComponent = UnitContainerComponent.get_component(structure, false)
		if comp:
			components.push_back(comp)
	return components

func _consume_input() -> void:
	get_viewport().set_input_as_handled()
