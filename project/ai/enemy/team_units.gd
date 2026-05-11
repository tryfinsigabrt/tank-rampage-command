class_name TeamUnits extends Node

const ai_unit_vision_scene:PackedScene = preload("uid://dg44egwlcoaq4")
const attacked_tracking_scene:PackedScene = preload("uid://86b6ejinpq81")

@warning_ignore("unused_signal")
signal initialized

signal new_asset_built(asset:Node3D)

signal asset_visibility_changed(asset:Node3D, in_is_visible:bool)
signal resource_discovered(resource:Node3D)
signal control_point_discovered(control_point:ControlPoint)
signal control_point_visibility_changed(control_point:ControlPoint, in_is_visible:bool)

var team:int

var _assets:Dictionary[int, Node3D] = {}
var _asset_counts:Dictionary[StringName, int] = {}
var _assets_dirty:Dictionary[StringName,bool] = {}

var _unit_values: Array[Unit]
var _building_values: Array[Node3D]
var _structure_values: Array[Node3D]

var assets_dict:Dictionary[int, Node3D]:
	get: return _assets
	
var units:Array[Unit]:
	get: return _get_assets_array(Groups.Unit, _unit_values)
	
var buildings: Array[Node3D]:
	get: return _get_assets_array(Groups.Building, _building_values)

var structures: Array[Node3D]:
	get: return _get_assets_array(Groups.Structure, _structure_values)

func add_unit(unit:Unit) -> void:
	_add_asset(unit, Groups.Unit)

func add_building(building:Node3D) -> void:
	_add_asset(building, Groups.Building)
	
	# Add attacked tracking
	building.add_child(attacked_tracking_scene.instantiate())

func add_structure(structure:Node3D) -> void:
	_add_asset(structure, Groups.Structure)
	
func _add_asset(asset:Node3D, group: StringName) -> void:
	_init_asset(asset)
	
	_assets[asset.get_instance_id()] = asset
	_asset_counts[group] = _asset_counts.get(group, 0) + 1
	_assets_dirty[group] = true
	
	if not HealthStat.connect_died_signal(asset, _on_asset_destroyed.bind(asset, group)):
		push_warning("%s: asset=%s in group=%s has no HealthStat! Falling back to when asset exits tree" % [name, asset.name, group])
	
	# Only notify if asset was built
	if not asset.has_meta(MatchTeam.IS_PREDEPLOYED_KEY):
		new_asset_built.emit(asset)
	
func initialize() -> void:
	var match_team:MatchTeam = GameManager.find_match_team_by_id(team)
	if match_team:
		await NodeUtils.ensure_ready(match_team)
		
		var team_visibility_component:TeamVisibilityComponent = match_team.team_visibility_component
		team_visibility_component.discovered.connect(_on_discovered)
		team_visibility_component.visibility_changed.connect(_on_visibility_changed)
		
	else:
		push_error("%s: No match team found!" % [name])
	initialized.emit()
			
func _init_asset(asset:Node3D) -> void:
	# If we have fog of war, we need to add the AI unit vision so that enemy visibility is updated
	if GameManager.fog_of_war:
		var ai_unit_vision:AiUnitVision = ai_unit_vision_scene.instantiate()
		asset.add_child(ai_unit_vision)
			
func has_asset_id(id:int) -> bool:
	return _assets.has(id)

func has_asset(asset:Node3D) -> bool:
	return is_instance_valid(asset) and has_asset_id(asset.get_instance_id())
	
func _get_assets_array(group:StringName, values: Array) -> Array:
	var dirty:bool = _assets_dirty.get(group, false)
	if dirty:
		var size:int = _asset_counts.get(group, 0)
		values.resize(size)
		var i:int = 0
		for id in _assets:
			var asset:Node3D = _assets[id]
			if asset.is_in_group(group):
				values[i] = asset
				i += 1
		_assets_dirty[group] = false
	return values
	
func _on_asset_destroyed(asset:Node3D, group: StringName) -> void:
	var existed:bool = _assets.erase(asset.get_instance_id())
	if existed:
		_asset_counts[group] = _asset_counts.get(group, 1) - 1
		_assets_dirty[group] = true

func get_average_position() -> Vector3:
	if not _asset_counts.get(Groups.Unit, 0):
		return Vector3.ZERO
		
	var position:Vector3 = Vector3.ZERO
	
	var cnt:int = 0
	for id in _assets:
		var unit:Unit = _assets[id] as Unit
		if unit:
			cnt += 1
			position += unit.global_position
	
	if cnt:
		position = position / cnt
	return position
	
func _on_discovered(object:Node3D) -> void:
	if object.is_in_group(Groups.GameResource):
		resource_discovered.emit(object)
	elif object is ControlPoint:
		control_point_discovered.emit(object)
		
func _on_visibility_changed(object:Node3D, in_is_visible:bool) -> void:
	if object.is_in_group(Groups.TeamAsset):
		asset_visibility_changed.emit(object, in_is_visible)
	# Control Point is a TeamAsset as well
	if object is ControlPoint:
		control_point_visibility_changed.emit(object, in_is_visible)
