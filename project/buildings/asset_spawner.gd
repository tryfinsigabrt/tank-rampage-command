@abstract
class_name AssetSpawner extends Node

@export
var supports_rally_points:bool = true

var has_rally_point:bool:
	get:
		return supports_rally_points and rally_point != Vector3.INF
		
var rally_point:Vector3 = Vector3.INF:
	set(value):
		if not supports_rally_points:
			return
		rally_point = value

func clear_rally_point() -> void:
	rally_point = Vector3.INF

@abstract
func spawn(resource:ConstructionResource, asset_name:StringName = "") -> Node3D
