class_name EnemyTeamUnits extends Node

var team:int

## Key is the instance id of the asset
var assets:Dictionary[int, UnitData] = {}

@onready var threat_scorer: ThreatScorer = $ThreatScorer

func has_asset_id(id:int) -> bool:
	return assets.has(id)
	
func has_asset(asset:Node3D) -> bool:
	return is_instance_valid(asset) and has_asset_id(asset.get_instance_id())
	
func get_unit_data(id:int) -> UnitData:
	var data:UnitData = assets.get(id)
	if data and is_instance_valid(data.asset):
		return data
	return null

func get_asset(id:int) -> Node3D:
	var data := get_unit_data(id)
	return data.asset if data else null
	
func get_unit(id:int) -> Unit:
	return get_asset(id) as Unit
	
func mark_all_not_visible() -> void:
	for data:UnitData in assets.values():
		data.visible = false

func get_all_visible_ids(out_ids:PackedInt64Array) -> void:
	for asset_id in assets:
		if assets[asset_id].visible:
			out_ids.push_back(asset_id)

func mark_known(asset:Node3D) -> UnitData:
	var id:int = asset.get_instance_id()
	var unit_data:UnitData = assets.get(id)
	if not unit_data:
		unit_data = UnitData.create(asset)
		HealthStat.connect_died_signal(asset, _on_asset_deleted.bind(asset))
		assets[id] = unit_data
	return unit_data
	
func _on_asset_deleted(asset: Node3D) -> void:
	print_debug("%s: asset deleted: %s" % [name, asset])
	assets.erase(asset.get_instance_id())
	
func mark_seen(asset:Node3D) -> UnitData:
	var unit_data:UnitData = mark_known(asset)
	unit_data.visible = true
	unit_data.last_known_position = asset.global_position
	unit_data.last_seen_timestamp = GameManager.game_timer.time_seconds
	
	return unit_data

func get_closest_visible_unit(position:Vector3) -> UnitData:
	var closest:UnitData = null
	var closest_distance:float = 1e100
	
	for unit_data:UnitData in assets.values():
		if unit_data.valid and unit_data.visible and unit_data.asset.is_in_group(Groups.Unit):
			var dist_sq:float =  unit_data.asset.global_position.distance_squared_to(position)
			if dist_sq < closest_distance:
				closest = unit_data
				closest_distance = dist_sq
	return closest
		
func get_visible_threat_assets(position:Vector3) -> Array[UnitScore]:
	return threat_scorer.get_visible_threat_assets(assets.values(), position)
	
func get_visible_threat_contexts(our_units:Array[Unit]) -> Array[UnitThreatContext]:
	var threats:Array[Unit]
	for unit_id in assets:
		var unit_data:UnitData = assets[unit_id]
		# TODO: Currently threat clusters only consider assets and not any asset
		if unit_data.valid and unit_data.visible and unit_data.asset is Unit:
			threats.push_back(unit_data.asset)
	
	return threat_scorer.calculate_threat_inputs(our_units, threats)
