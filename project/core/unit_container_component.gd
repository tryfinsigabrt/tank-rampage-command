## A component that can hold units and temporarily
## remove them from the battlefield
class_name UnitContainerComponent extends Node

signal on_unit_added(unit:Unit)
signal on_unit_removed(unit:Unit)

const ComponentName:StringName = &"UnitContainerComponent"

const ADDED_META_KEY:StringName = &"load_into_ucont"

@export
var capacity:int = 4

@export
var position_distributor:PositionDistributor
@export
var exit_position_delta: Vector3 = Vector3(0, 0, 7)

var units:Array[Unit]

#region Inner Classes
	
class Data:
	var collision_node_process_state:Dictionary[int, Node.ProcessMode] = {}

#endregion

var _unit_state_data:Dictionary[int,Data] = {}

var _team_asset:Node3D

var any:bool:
	get: return not units.is_empty()
	
var is_full:bool:
	get: return units.size() >= capacity

var is_not_full:bool:
	get: return units.size() < capacity
	
@export
var supported_unit_classes:Array[Unit.UnitClass] = [Unit.UnitClass.Soldier]

static func is_in_container(unit:Unit) -> bool:
	return unit.has_meta(ADDED_META_KEY)

static func get_container_for_unit(unit:Unit) -> UnitContainerComponent:
	return _get_container_meta_value(unit, ADDED_META_KEY)

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
	_on_add(unit)
	
	return true
	
func _on_add(unit:Unit) -> void:
	# Set a meta key in case unit needs to query quickly if it is in a container
	unit.set_meta(ADDED_META_KEY, get_instance_id())

	_disable_unit(unit)
	
	on_unit_added.emit(unit)

static func _get_container_meta_value(unit:Unit, key:StringName) -> UnitContainerComponent:
	if unit.has_meta(key):
		return instance_from_id(unit.get_meta(key)) as UnitContainerComponent
	return null
	
func remove_unit(unit:Unit) -> bool:
	if unit not in units:
		return false
	
	units.erase(unit)
	var exit_position := _get_exit_position()
	_on_remove(unit, exit_position)
	
	return true

func _on_remove(unit:Unit, exit_position: Vector3) -> void:
	if _get_container_meta_value(unit, ADDED_META_KEY) == self:
		unit.remove_meta(ADDED_META_KEY)
	
	_enable_unit(unit)
	SignalBus.on_unit_move_issued.emit(unit, exit_position)
	
	on_unit_removed.emit(unit)

func remove_all_units() -> void:
	if not units:
		return
	
	var exit_position := _get_exit_position()
	var position_distribution := position_distributor.calculate(units, exit_position)
	for unit in units:
		var unit_exit_position := position_distribution[unit.get_instance_id()]
		_on_remove(unit, unit_exit_position)
	
	units.clear()

func _get_exit_position() -> Vector3:
	var asset_transform := _team_asset.global_transform
	var exit_position_transform := asset_transform.translated_local(exit_position_delta)
	return exit_position_transform.origin

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
	
	# Any units still left should be notified that they are being removed from the container
	remove_all_units()
	
#endregion

#region Enable/Disable unit state
func _disable_unit(unit:Unit) -> void:
	unit.hide()
	var state_data:Data = Data.new()
	_unit_state_data[unit.get_instance_id()] = state_data
	
	_toggle_collision_state(unit, state_data, false)
	
	var actions := unit.get_or_add_actions()
	# Cancel current command and then disable
	actions.stop()
	actions.enabled = false
	
func _enable_unit(unit:Unit) -> void:
	var unit_id:int = unit.get_instance_id()
	var state_data:Data = _unit_state_data[unit_id]
	
	unit.show()
	_toggle_collision_state(unit, state_data, true)
	
	var actions := unit.get_or_add_actions()
	# Force refresh
	actions.enabled = false
	
	_unit_state_data.erase(unit_id)
	
func _toggle_collision_state(unit:Unit, state_data:Data, enable:bool) -> void:
	for collision:CollisionObject3D in unit.find_children("*", "CollisionObject3D"):
		var collision_id:int = collision.get_instance_id()
		if enable:
			if collision_id in state_data.collision_node_state:
				var process_state:Node.ProcessMode = state_data.collision_node_state[collision_id]
				collision.process_mode = process_state
		else:
			state_data.collision_node_process_state[collision_id] = collision.process_mode
			collision.process_mode = Node.PROCESS_MODE_DISABLED
#endregion
