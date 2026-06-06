## A component that can hold units and temporarily
## remove them from the battlefield
class_name UnitContainerComponent extends Node

signal on_unit_added(unit:Unit)
signal on_unit_removed(unit:Unit)

const ComponentName:StringName = &"UnitContainerComponent"

@export
var capacity:int = 4

var units:Array[Unit]

var _team_asset:Node3D

func add_unit(unit:Unit) -> bool:
	if units.size() >= capacity:
		print_debug("%s-%s: Cannot add unit=%s as at capacity=%d" % [name, _team_asset.name, capacity])
		return false
	if unit in units:
		print_debug("%s-%s: Cannot add unit=%s as it is already in the container!" % [name, _team_asset.name])
		return false
		
	# Make sure on same team
	var team_component:TeamComponent = TeamComponent.get_component(_team_asset)
	if not team_component.is_on_team(unit.team):
		push_warning("%s-%s: Attempted to add enemy unit=%s to bunker!" % [name, _team_asset.name, unit.name])
		return false
		
	units.push_back(unit)
	on_unit_added.emit(unit)
	
	return true
			
func remove_unit(unit:Unit) -> bool:
	if unit not in units:
		return false
		
	units.erase(unit)
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
		
func _enter_tree() -> void:
	_team_asset = Groups.get_parent_in_group(self, Groups.TeamAsset)
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
			
#endregion
