class_name ConstructionResource extends Resource

enum Type
{
	None,
	Soldier,
	Tank,
	Artillery,
	CommandCenter,
	Barracks,
	Factory,
	TankSpikes,
	BarbedWire,
	Mine,
	Turret
}

@export
var team_asset:PackedScene

@export
var type:Type

@export_range(1, 1e9, 1, "or_greater")
var cost:int
