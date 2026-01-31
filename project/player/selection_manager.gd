class_name SelectionManager extends Node

var team:int

var _selected_units:PackedInt64Array = []

var any:bool:
	get: return not _selected_units.is_empty()
	
var any_same_team:bool:
	get:
		if not any:
			return false
		for id in _selected_units:
			var unit:Unit = instance_from_id(id)
			if unit and unit.is_on_team(team):
				return true
		return false
	
var selected_units:Array[Unit]:
	get:
		var units:Array[Unit]
		units.resize(_selected_units.size())
		var unit_count:int = 0
		for id in _selected_units:
			var unit:Unit = instance_from_id(id)
			if unit:
				units[unit_count] = unit
				unit_count += 1
		if unit_count != units.size():
			print_debug("%s: Invalid instances selected - removing %d instances" % [name, units.size() - unit_count])
			units.resize(unit_count)
			# remove invalid
			for i in range(_selected_units.size() - 1, -1, -1):
				var id:int = _selected_units[i]
				if not is_instance_id_valid(id):
					_selected_units.remove_at(i)
		
		return units

func get_selected_units_on_team() -> Array[Unit]:
	var all_selected:Array[Unit] = selected_units
	var uniform:bool = true
	
	for unit in all_selected:
		if not unit.is_on_team(team):
			uniform = false
			break
	if uniform:
		return all_selected
	
	var filtered:Array[Unit]
	for unit in all_selected:
		if unit.is_on_team(team):
			filtered.push_back(unit)
	
	return filtered
					
func clear() -> void:
	_selected_units.clear()

func add(unit:Unit) -> bool:
	print_debug("%s: Selected unit=%s on team=%d; out_team=%d" % [name, unit.name, unit.team, team])
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(
			unit.global_position, 5.0
			,Color.GREEN if unit.is_on_team(team) else Color.BLUE_VIOLET
			, 3.0)
			
	var id:int = unit.get_instance_id()
	if not id in _selected_units:
		_selected_units.push_back(id)
		SignalBus.on_unit_selected.emit(unit)
		return true
	return false

func remove(unit:Unit) -> bool:
	var id:int = unit.get_instance_id()
	var erased:bool = _selected_units.erase(id)
	if erased:
		print_debug("%s: De-select unit=%s" % [name, unit.name])
		SignalBus.on_unit_deselected.emit(unit)
	return erased

func has(unit:Unit) -> bool:
	var id:int = unit.get_instance_id()
	return id in _selected_units
	
## Adds if not present and removes otherwise
func toggle(unit:Unit) -> void:
	if has(unit):
		remove(unit)
	else:
		add(unit)
	
