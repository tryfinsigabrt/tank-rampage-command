class_name SelectionManager extends Node

var team:int

var _selected_units:PackedInt64Array = []
var _selected_buildings:PackedInt64Array = []

var any:bool:
	get: return not _selected_units.is_empty() or not _selected_buildings.is_empty()
	
var any_units:bool:
	get: return not _selected_units.is_empty()
	
var any_units_same_team:bool:
	get:
		if not any_units:
			return false
		for id in _selected_units:
			var unit:Unit = instance_from_id(id)
			if unit and unit.is_on_team(team):
				return true
		return false
	
var selected_units:Array[Unit]:
	get:
		var units:Array[Unit]
		_get_selection(_selected_units, units)
		return units

var selected_buildings:Array[Building]:
	get:
		var buildings:Array[Building]
		_get_selection(_selected_buildings, buildings)
		return buildings
		
var all_selected:Array[Node3D]:
	get:
		var all:Array[Node3D]
		
		_get_selection(_selected_units, all)
		_get_selection(_selected_buildings, all)
		
		return all
		
func _get_selection(id_list:PackedInt64Array, selection: Array) -> void:
	var existing_size:int = selection.size()
	selection.resize(existing_size + id_list.size())
	var count:int = 0
	
	for id in id_list:
		var value:Object = instance_from_id(id)
		if value:
			selection[count + existing_size] = value
			count += 1
			
	var new_entries:int = selection.size() - existing_size
	if count != new_entries:
		var invalid_count:int = new_entries - count
		print_debug("%s: Invalid instances selected - removing %d instances" % [name, invalid_count])
		selection.resize(existing_size + count)
		
		# remove invalid
		var removed_count:int = 0
		for i in range(id_list.size() - 1, -1, -1):
			var id:int = id_list[i]
			if not is_instance_id_valid(id):
				id_list.remove_at(i)
				removed_count += 1
				if removed_count == invalid_count:
					break
				
func get_selected_units_on_team() -> Array[Unit]:
	var all_units:Array[Unit] = selected_units
	var uniform:bool = true
	
	for unit in all_units:
		if not unit.is_on_team(team):
			uniform = false
			break
	if uniform:
		return all_units
	
	var filtered:Array[Unit]
	for unit in all_selected:
		if unit.is_on_team(team):
			filtered.push_back(unit)
	
	return filtered
	
func clear() -> void:
	var all := all_selected
	_clear_internal()

	for asset in all:
		_do_deselect(asset)

func _clear_internal() -> void:
	_selected_units.clear()
	_selected_buildings.clear()
	
func add_all(assets: Array) -> void:
	for asset:Node3D in assets:
		add(asset)

func set_selection(asset: Node3D) -> void:
	if not asset:
		return
		
	var existing_selection := all_selected
	if existing_selection.size() != 1 or existing_selection.front() != asset:
		clear()
		add(asset)
	
static func _select_compare(first:Object, second:Object) -> bool:
	return first.get_instance_id() < second.get_instance_id()
		
func set_selection_multiple(units: Array[Unit]) -> void:
	if not units:
		return
	
	var existing:Dictionary[int, Unit] = {}
	var new:Dictionary[int, Unit] = {}
	
	for unit in selected_units:
		existing[unit.get_instance_id()] = unit
	for unit in units:
		new[unit.get_instance_id()] = unit
	
	# First remove those not in the new list
	for id in existing:
		if not id in new:
			remove(existing[id])
	# Now add the new ones
	for id in new:
		if not id in existing:
			add(new[id])
		
func add(asset:Node3D) -> bool:
	if not asset:
		return false
	var team_component: TeamComponent = Components.get_component(Components.Team, asset)
	if not team_component or not team_component.is_visible_to(team):
		return false
	print_debug("%s: Selected asset=%s on team=%d; our_team=%d" % [name, asset.name, team_component.team, team])
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(
			asset.global_position, 5.0
			,Color.GREEN if team_component.is_on_team(team) else Color.BLUE_VIOLET
			, 3.0)
	
	if asset is Unit:
		return _add_unit(asset)
	if asset is Building:
		return _add_building(asset)
		
	assert(false, "asset=%s is not a supported type!" % [asset.name])		
	return false

func _add_unit(unit:Unit) -> bool:
	var id:int = unit.get_instance_id()
	if not id in _selected_units:
		_selected_units.push_back(id)
		SignalBus.on_unit_selected.emit(unit)
		return true
	return false

func _add_building(building:Building) -> bool:
	var id:int = building.get_instance_id()
	if not id in _selected_buildings:
		_selected_buildings.push_back(id)
		SignalBus.on_building_selected.emit(building)
		return true
	return false
	
func remove_all(assets:Array) -> void:
	for asset:Node3D in assets:
		remove(asset)
		
func remove(unit:Unit) -> bool:
	if not unit:
		return false
	var id:int = unit.get_instance_id()
	var erased:bool = _selected_units.erase(id)
	if erased:
		_do_deselect(unit)
	return erased

func _do_deselect(asset:Node3D) -> void:
	if asset is Unit:
		print_debug("%s: De-select unit=%s" % [name, asset.name])
		SignalBus.on_unit_deselected.emit(asset)
	elif asset is Building:
		print_debug("%s: De-select building=%s" % [name, asset.name])
		SignalBus.on_building_deselected.emit(asset)
	
func has(unit:Unit) -> bool:
	if not unit:
		return false
	var id:int = unit.get_instance_id()
	return id in _selected_units
	
## Adds if not present and removes otherwise
func toggle(unit:Unit) -> void:
	if has(unit):
		remove(unit)
	else:
		add(unit)
	
func toggle_all(units: Array[Unit]) -> void:
	for unit in units:
		toggle(unit)
