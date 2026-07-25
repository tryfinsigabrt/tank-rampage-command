class_name ConstructionResource extends Resource

enum Type
{
	None = 0,
	
	# Units [1,3,12]
	Marine = 1,
	Tank = 2,
	Artillery = 3,
	
	# Buildings [4,6]
	CommandCenter = 4,
	Barracks = 5,
	Factory = 6,
	
	# Structures [7,11]
	TankSpikes = 7,
	BarbedWire = 8,
	Mine = 9,
	Turret = 10,
	Bunker = 11,
	
	Transport = 12,
	## Godot saves enumerables in resource files as integers,
	## if you change the order of them in the script you will mismatch
	## saved resources. That's why I'm putting this new Unit type at the bottom.
	## -tarnished moth
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

@export_range(0.0, 1.0, 0.05)
var scrap_fraction:float

@export_range(0, 1e9, 1, "or_greater")
var personnel:int = 0

@export_range(0.1, 1e9, 0.1, "or_greater")
var time:float = 1.0

## How many of the type are constructed at once
## Only applies to Structures.  Buildings and Units are constructed 1 at a time.
@export_range(1, 1e9, 1, "or_greater")
var count:int = 1

@export
var attributes:TeamAssetAttributes

@export
var placement_spawner_resource:NodePlacementSpawnerResource

@export
var construction_scene:PackedScene

@export
var visual_overrides:AssetVisualTeamResource

var classification:Classification:
	get: return classify_type(type)

var scrap_value:int:
	get:
		return roundi(cost * scrap_fraction)

static func classify_type(in_type:ConstructionResource.Type) -> Classification:
	match in_type:
		1, 2, 3, 12:
			return Classification.Unit
		4, 5, 6:
			return Classification.Building
		7, 8, 9, 10, 11:
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

static func type_from_building(building:Building) -> Type:
	if building is CommandCenter:
		return Type.CommandCenter
	if building is Barracks:
		return Type.Barracks
	if building is Factory:
		return Type.Factory
	return Type.None
	
func matches(asset:Node3D) -> bool:
	return asset and team_asset and asset.scene_file_path == team_asset.resource_path

func is_unit_container() -> bool:
	if not team_asset:
		return false
	return Groups.scene_has_group(team_asset, Groups.UnitContainer, true)
	
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

func queue_personnel(resources:TeamResources) -> void:
	if not resources:
		return
	
	resources.personnel.queued_count += personnel
	
func dequeue_personnel(resources:TeamResources) -> void:
	if not resources:
		return
	resources.personnel.queued_count -= personnel
	
## This is only to be used if canceling before could be built or if the asset couldn't be spawned
func refund_fully(resources:TeamResources) -> void:
	if not resources:
		return
	
	resources.scrap.count += cost
	
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
	return "type=%s; team_asset=%s" % [type, team_asset.resource_path if team_asset else ""]
