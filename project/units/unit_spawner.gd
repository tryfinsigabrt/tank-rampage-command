class_name UnitSpawner extends Node

@export
var node_picker:NodePicker

var _match_team:MatchTeam

var _container:Node

func _ready() -> void:
	_match_team = Groups.get_parent_with_type(self, MatchTeam)
	_container = _match_team
	if not _match_team:
		push_error("%s: UnitSpawner has no MatchTeam parent!" % name)
		_container = self
	assert(node_picker, "%s: Node Picker not set!" % name)
	
func spawn(scene:PackedScene, at:Vector3) -> Unit:
	var unit:Unit = scene.instantiate() as Unit
	if not unit:
		push_error("%s: Could not spawn scene=%s as Unit" % [name, scene])
		return null
	
	# TODO: Find open spot to spawn - could use node_picker
	if _match_team:
		unit.team = _match_team.team
	_container.add_child(unit)
	
	var spawn_position:Vector3 = node_picker.project_to_ground(at)
	unit.global_position = spawn_position

	print_debug("%s: Spawned unit=%s for team=%d at %s -> %s" \
		% [name, unit.name, unit.team, at, unit.global_position])
		
	return unit
