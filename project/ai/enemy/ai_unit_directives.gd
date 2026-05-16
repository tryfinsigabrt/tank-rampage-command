class_name AiUnitDirectives extends Node

const ComponentName:StringName = &"AiUnitDirectives"
const DEFEND_POSITION:StringName = &"defend_position"

class State:
	var key:StringName
	var priority:int
	var data:Dictionary[StringName, Variant] 

var _team_asset_root:Node
var _requested_states:Dictionary[StringName, State]

func set_defend_position(position:Vector3) -> void:
	var state:State = State.new()
	state.key = DEFEND_POSITION
	state.data = {
		POSITION = position
	}
	
	_requested_states[DEFEND_POSITION] = state

	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> AiUnitDirectives:
	return Components.get_component(ComponentName, node, required) as AiUnitDirectives
		
func _enter_tree() -> void:
	_team_asset_root = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if _team_asset_root:
		Components.add_component(ComponentName, self, _team_asset_root)

func _exit_tree() -> void:
	if _team_asset_root:
		Components.remove_component(ComponentName, self, _team_asset_root)
#endregion
