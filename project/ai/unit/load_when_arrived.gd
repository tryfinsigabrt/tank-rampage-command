@tool
extends ActionLeaf

var _load_into_distance:float

var _unit:Unit
var _container_asset:Node3D
var _unit_container_component:UnitContainerComponent

var _unit_bounds:BoundingCircle
var _asset_bounds:BoundingCircle

func before_run(actor: Node, blackboard: Blackboard) -> void:
	_load_into_distance = blackboard.get_value(UnitBlackboard.Keys.LoadIntoDistance, 0.0)
	_unit = actor as Unit
	_container_asset = blackboard.get_value(UnitBlackboard.Keys.TargetNode)
	
	if is_instance_valid(_unit):
		_unit_bounds = _create_bounding_circle(_unit)
	if is_instance_valid(_container_asset):
		_unit_container_component = UnitContainerComponent.get_component(_container_asset)
		_asset_bounds = _create_bounding_circle(_container_asset)
		
func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if not is_instance_valid(_unit) or not is_instance_valid(_unit_container_component) or not is_instance_valid(_asset_bounds):
		return FAILURE
	
	var blackboard:UnitBlackboard = _blackboard
	
	_set_bounds_pos(_container_asset, _asset_bounds)
	_set_bounds_pos(_unit, _unit_bounds)
	
	var dist:float = _asset_bounds.distance_to_bounds(_unit_bounds)
	
	if dist <= _load_into_distance:
		print_debug("%s: unit=%s entered loading zone of %s" % [name, _unit.name, _container_asset.name])
		if _unit_container_component.add_unit(_unit):
			# The container will issue a stop command which will complete this tree
			return SUCCESS
		else:
			print_debug("%s: unit=%s could not be loaded into %s - canceling movement" % [name, _unit.name, _container_asset.name])
			SignalBus.on_unit_move_canceled.emit(_unit, blackboard.target_position)
			return FAILURE
	return RUNNING

func _create_bounding_circle(asset:Node3D) -> BoundingCircle:
	var aabb:AABB
	if asset.has_method("get_bounds"):
		aabb = asset.get_bounds()
	else:
		aabb = Collisions.calculate_aabb(asset)
	
	if aabb.has_volume():
		return BoundingCircle.from_aabb(aabb, true)
	push_warning("%s: asset=%s has no collision volume!" % [name, asset.name])
	
	return BoundingCircle.new(Vector2.ZERO, 5.0)
	
func _set_bounds_pos(asset:Node3D, circle:BoundingCircle) -> void:
	var pos:Vector3 = asset.global_position
	circle.center = Vector2(pos.x, pos.z)
