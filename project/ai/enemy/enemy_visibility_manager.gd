class_name EnemyVisibilityManager extends Node

@onready var team_units: TeamUnits = %TeamUnits

var _visible_assets:Dictionary[int,bool] = {}

var visible_units:Array[Unit]:
	get:
		return _populate_typed_asset_array([] as Array[Unit], Unit)
		
var visible_control_points:Array[ControlPoint]:
	get:
		return _populate_typed_asset_array([] as Array[ControlPoint], ControlPoint)
			
var visible_buildings:Array[Building]:
	get:
		return _populate_typed_asset_array([] as Array[Building], Building)
			
func _populate_typed_asset_array(array: Array, type:Variant) -> Array:
	for asset_id in _visible_assets:
		var asset:Variant = instance_from_id(asset_id)
		if asset and is_instance_of(asset, type):
			array.push_back(asset)
	return array
	
func _ready() -> void:
	team_units.asset_visibility_changed.connect(_on_asset_visibility_changed)

func _on_asset_visibility_changed(asset:Node3D, in_is_visible:bool) -> void:
	if in_is_visible:
		_visible_assets[asset.get_instance_id()] = true
	else:
		_visible_assets.erase(asset.get_instance_id())
