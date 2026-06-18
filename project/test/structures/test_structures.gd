extends Node3D

@export_range(1,2)
var structures_team:int = 2

func _ready() -> void:
	for structure:DefensiveStructure in get_tree().get_nodes_in_group(Groups.Structure):
		var team_component := TeamComponent.get_component(structure)
		team_component.team = structures_team
