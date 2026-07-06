class_name MiningComponent extends Node

const ComponentName:StringName = &"MiningComponent"

var _mined_scrap_fields:Array[ScrapField]

var mining:bool:
	get: return not _mined_scrap_fields.is_empty()


var scrap_per_minute:float:
	get:
		var total := 0.0
		for field in _mined_scrap_fields:
			if field == null or not is_instance_valid(field) or not field.active:
				continue
			if field.scrap_mining_interval <= 0.0:
				continue
			total += field.scrap_per_interval * (60.0 / field.scrap_mining_interval)
		return total
	
var mined_fields:Array[ScrapField]:
	get:
		return _mined_scrap_fields
	
func add_field(field:ScrapField) -> void:
	if field in _mined_scrap_fields:
		return
	_mined_scrap_fields.push_back(field)

func remove_field(field:ScrapField) -> void:
	_mined_scrap_fields.erase(field)
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> MiningComponent:
	return Components.get_component(ComponentName, node, required) as MiningComponent
		
func _enter_tree() -> void:
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion
