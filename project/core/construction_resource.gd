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

const ASSET_META_KEY:StringName = &"ConstructionResource"

@export
var team_asset:PackedScene

@export
var icon:Texture2D

@export
var type:Type

@export_range(1, 1e9, 1, "or_greater")
var cost:int = 10

@export_range(0, 1e9, 1, "or_greater")
var personnel:int = 0

@export_range(0.1, 1e9, 0.1, "or_greater")
var time:float = 1.0

@export
var attributes:TeamAssetAttributes

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


static func type_from_unit_class(unit_class:Unit.UnitClass) -> Type:
	match unit_class:
		Unit.UnitClass.Tank:
			return Type.Tank
		Unit.UnitClass.Soldier:
			return Type.Marine
		Unit.UnitClass.Artillery:
			return Type.Artillery
		_:
			return Type.None
			
func can_build(resources:TeamResources) -> bool:
	if not resources:
		return true
		
	var scrap := resources.scrap
	var pers := resources.personnel
	
	return scrap.count >= cost and pers.remaining >= personnel

func spend(resources:TeamResources) -> void:
	if not resources:
		return
	
	resources.scrap.count -= cost
	resources.personnel.reserved_count += personnel

## This is only to be used if canceling before could be built or if the asset couldn't be spawned
func refund_fully(resources:TeamResources) -> void:
	if not resources:
		return
	
	resources.scrap.count += cost
	resources.personnel.reserved_count -= personnel
	
func spend_personnel_only(resources:TeamResources) -> void:
	if not resources:
		return
	resources.personnel.count += personnel

func assign_to(asset:Node3D) -> void:
	asset.set_meta(ASSET_META_KEY, self)

static func is_assigned_resource(asset:Node3D) -> bool:
	return asset.has_meta(ASSET_META_KEY)
	
static func get_assigned_resource(asset:Node3D) -> ConstructionResource:
	return asset.get_meta(ASSET_META_KEY) as ConstructionResource \
		if asset.has_meta(ASSET_META_KEY) else null
	 
func refund_personnel(resources:TeamResources) -> void:
	if not resources:
		return
	
	resources.personnel.count -= personnel

func refund_cost(resources:TeamResources) -> void:
	if not resources:
		return
	
	# Only buildings and structures refunded at 50% (rounded down) cost
	if type < Type.CommandCenter:
		push_warning("Attempted to refund non-refundable type %s" % [EnumUtils.enum_to_string(Type, type)])
		return
	
	@warning_ignore("integer_division")
	resources.scrap.count += cost / 2
	
func _to_string() -> String:
	return "type=%s; team_asset=%s" % [type, team_asset.resource_path]
