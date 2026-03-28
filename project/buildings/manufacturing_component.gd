class_name ManufacturingComponent extends Node

@export
var default_spawn_location:Node3D

@export
var supported_types:ManufacturingTypes

@onready var unit_spawner: UnitSpawner = %UnitSpawner


var _indexed_types:Dictionary[ConstructionResource.Type, ConstructionResource]

func _ready() -> void:
	if supported_types:
		for construction in supported_types.types:
			var type := construction.type
			if type:
				_indexed_types[type] = construction
	
	if not default_spawn_location:
		assert(false, "%s: default_spawn_location node not set!" % name)
		default_spawn_location = Groups.get_parent_with_type(self, Node3D)
	
func can_build(type: ConstructionResource.Type) -> bool:
	# TODO: Check resource limits
	return type in _indexed_types
	
func build(type: ConstructionResource.Type) -> Unit:
	var resource:ConstructionResource = _indexed_types.get(type)
	if not resource:
		push_warning("%s: Type=%s cannot be built by this component!" % [name, type])
		return null
		
	return unit_spawner.spawn(resource.team_asset, default_spawn_location.global_position)
