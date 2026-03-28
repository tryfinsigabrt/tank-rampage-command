class_name UnitSpawner extends Node

var _match_team:MatchTeam

var _container:Node

func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	_container = _match_team
	if not _match_team:
		push_error("%s: UnitSpawner has no MatchTeam parent!" % name)
		_container = self
	
func spawn(scene:PackedScene, at:Vector3) -> Unit:
	var unit:Unit = scene.instantiate() as Unit
	if not unit:
		push_error("%s: Could not spawn scene=%s as Unit" % [name, scene])
		return null
	
	# TODO: Find open spot to spawn
	if _match_team:
		unit.team = _match_team.team
	_container.add_child(unit)
	unit.global_position = at + Vector3.UP * unit.get_bounds().size.y

	print_debug("%s: Spawned unit=%s for team=%d at %s -> %s" \
		% [name, unit.name, unit.team, at, unit.global_position])
		
	return unit
