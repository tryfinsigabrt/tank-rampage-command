class_name ConstructionResource extends Resource

enum Type
{
	None,
	
	# Units
	Marine,
	Tank,
	Artillery,
	
	# Buildings
	CommandCenter,
	Barracks,
	Factory,
	
	# Structures
	TankSpikes,
	BarbedWire,
	Mine,
	Turret
}

enum Classification
{
	None,
	Unit,
	Building,
	Structure
}

@export
var team_asset:PackedScene

@export
var type:Type

@export_range(1, 1e9, 1, "or_greater")
var cost:int = 10

@export_range(0.1, 1e9, 0.1, "or_greater")
var time:float = 1.0

var classification:Classification:
	get:
		match type:
			1, 2, 3:
				return Classification.Unit
			4, 5, 6:
				return Classification.Building
			7, 8, 9, 10:
				return Classification.Structure
			_:
				return Classification.None

func _to_string() -> String:
	return "type=%s; team_asset=%s" % [type, team_asset.resource_path]
