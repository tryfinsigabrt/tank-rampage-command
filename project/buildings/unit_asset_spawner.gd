class_name UnitAssetSpawner extends AssetSpawner

var _manufacturing_component:ManufacturingComponent

@onready var unit_spawner: UnitSpawner = %UnitSpawner

func _ready() -> void:
	_manufacturing_component = get_parent() as ManufacturingComponent
	assert(_manufacturing_component, "Must be added as a child of Manufacturing Component!")
	
func spawn(resource:ConstructionResource, asset_name:StringName = "") -> Node3D:
	# Second time around force the spawn	
	for i in 2:
		for spawn_region in _manufacturing_component.default_spawn_locations:
			var spawn_location:Vector3 = spawn_region.global_position
			var spawn_dir:Vector3 = -spawn_region.global_basis.z
			var spawn_dir2:Vector2 = Vector2(spawn_dir.x, spawn_dir.z)
			unit_spawner.configure_spawn(_manufacturing_component.spawn_bounds, spawn_dir2)
			var unit := unit_spawner.spawn(resource.team_asset, spawn_location, asset_name, i > 0)
			if unit:
				return unit
	return null
