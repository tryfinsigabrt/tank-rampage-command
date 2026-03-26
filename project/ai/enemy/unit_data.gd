class_name UnitData

var asset:Node3D
var last_known_position:Vector3
var visible:bool
var last_seen_timestamp:float = -1.0

var valid:bool:
	get:
		return is_instance_valid(asset)
		
static func create(in_asset:Node3D) -> UnitData:
	var instance := UnitData.new()
	instance.asset = in_asset
	
	return instance
	
var last_seen_dt:float:
	get:
		return GameManager.game_timer.time_seconds - last_seen_timestamp if last_seen_timestamp >= 0 else 1e12
