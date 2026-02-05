class_name MatchTeam extends Node3D

@export
var team:int

var _units:Dictionary[int, Unit] = {}

func _ready() -> void:
	var units:Array[Node] = Groups.get_children_in_group(self, Groups.Unit)
	for node in units:
		var unit:Unit = node as Unit
		if not unit:
			push_warning("%s: Found node=%s labeled in group 'Unit' but is not a Unit type" % [name, node.name])
			continue
		unit.team = team
		unit.died.connect(_on_unit_destroyed.bind(unit).unbind(1))
		
		_units[unit.get_instance_id()] = unit
	
	await get_tree().process_frame
	SignalBus.match_team_ready.emit(self)
	
func _on_unit_destroyed(unit:Unit) -> void:
	print_debug("%s: unit=%s destroyed" % [name, unit.name])
	
	if not _units.erase(unit.get_instance_id()):
		return
	
	# TODO: There will be buildings as well and match only over for team when all of those destroyed or team forfeits
	if _units.is_empty():
		await get_tree().process_frame
		SignalBus.match_team_lost.emit(self)
