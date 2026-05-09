class_name SameTeamStructureIgnore extends Node

var _structures:Dictionary[int, DefensiveStructure] = {}
var _match_team:MatchTeam

func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	if not _match_team:
		assert("%s: Could not find MatchTeam parent" % name)
		queue_free()
		return
	
	_match_team.ready.connect(_match_team_ready, CONNECT_ONE_SHOT)	
	
func _match_team_ready() -> void:
	# Populate initial list of structures and units
	var all_structures:Array[Node] = get_tree().get_nodes_in_group(Groups.Structure)
	for structure in all_structures:
		if structure is DefensiveStructure and _is_on_match_team(structure):
			_on_structure_added(structure)
	
	for unit in _match_team.units:
		_on_unit_added(unit)
		
	# Listen for changes
	SignalBus.on_team_asset_added.connect(_on_team_asset_added)
	SignalBus.on_team_asset_destroyed.connect(_on_team_asset_removed.unbind(1))

func _on_team_asset_added(asset:Node3D) -> void:
	if not _is_on_match_team(asset):
		return
		
	if asset is Unit:
		_on_unit_added(asset)
	elif asset is DefensiveStructure:
		_on_structure_added(asset)

func _on_team_asset_removed(asset:Node3D) -> void:
	var id:int = asset.get_instance_id() 
	_structures.erase(id)
		
	# If asset was removed then unit collision exceptions automatically updated
	# so don't need to loop through and updaet
	
func _is_on_match_team(asset:Node3D) -> bool:
	var team_component:TeamComponent = TeamComponent.get_component(asset, false)
	return team_component and team_component.is_on_team(_match_team.team)
	
func _on_unit_added(unit:Unit) -> void:
	for id in _structures:
		_add_unit_collision_exception(unit, _structures[id])

func _add_unit_collision_exception(unit:Unit, structure:DefensiveStructure) -> void:
	# If these objects would ordinarily collide then add an exception
	var collides:bool = (structure.collision_layer & unit.collision_mask) != 0
	if collides:
		unit.add_collision_exception_with(structure)
		
func _on_structure_added(structure:DefensiveStructure) -> void:
	if not structure.ignore_collision_same_team:
		return
	
	_structures[structure.get_instance_id()] = structure
	
	for unit in _match_team.units:
		_add_unit_collision_exception(unit, structure)
