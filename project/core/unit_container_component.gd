## A component that can hold units and temporarily
## remove them from the battlefield
class_name UnitContainerComponent extends Node

signal on_unit_added(unit:Unit)
signal on_unit_removed(unit:Unit)

const ComponentName:StringName = &"UnitContainerComponent"

const ADDED_META_KEY:StringName = &"load_into_ucont"

@export
var capacity:int = 4

var units:Array[Unit]

var _team_asset:Node3D

var is_full:bool:
	get: return units.size() >= capacity

var is_not_full:bool:
	get: return units.size() < capacity
	
@export
var supported_unit_classes:Array[Unit.UnitClass] = [Unit.UnitClass.Soldier]

func supports_unit(unit:Unit) -> bool:
	return unit.unit_class in supported_unit_classes

func can_add_unit(unit:Unit) -> bool:
	return is_not_full and supports_unit(unit)

func add_unit(unit:Unit) -> bool:
	if is_full:
		print_debug("%s-%s: Cannot add unit=%s as at capacity=%d" % [name, _team_asset.name, unit.name, capacity])
		return false
	if unit in units:
		print_debug("%s-%s: Cannot add unit=%s as it is already in the container!" % [name, _team_asset.name, unit.name])
		return false
		
	# Make sure on same team
	var team_component:TeamComponent = TeamComponent.get_component(_team_asset)
	if not team_component.is_on_team(unit.team):
		push_warning("%s-%s: Attempted to add enemy unit=%s to bunker!" % [name, _team_asset.name, unit.name])
		return false
			
	units.push_back(unit)
	
	# Set a meta key in case unit needs to query quickly if it is in a container
	unit.set_meta(ADDED_META_KEY, get_instance_id())

	on_unit_added.emit(unit)
	
	return true
	
func _get_container_meta_value(unit:Unit, key:StringName) -> UnitContainerComponent:
	if unit.has_meta(key):
		return instance_from_id(unit.get_meta(key)) as UnitContainerComponent
	return null
	
func remove_unit(unit:Unit) -> bool:
	if unit not in units:
		return false
		
	units.erase(unit)
	
	if _get_container_meta_value(unit, ADDED_META_KEY) == self:
		unit.remove_meta(ADDED_META_KEY)
	
	on_unit_removed.emit(unit)
	
	return true

func remove_all_units() -> void:
	for unit in units:
		on_unit_removed.emit(unit)
	
	units.clear()
	
func _ready() -> void:
	if not _team_asset:
		assert(_team_asset, "%s: Not added to team asset tree" % name)
		queue_free()
		return
			
#region Component Registration
static func get_component(node: Node, required:bool = true) -> UnitContainerComponent:
	return Components.get_component(ComponentName, node, required) as UnitContainerComponent

static func has_component(node: Node) -> bool:
	return Components.has_component(ComponentName, node)
			
func _enter_tree() -> void:
	_team_asset = Groups.get_parent_in_group(self, Groups.TeamAsset)
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
			
#endregion
