class_name YawPitchAimingComponent extends Node

const ComponentName:StringName = &"YawPitchAimingComponent"

@export
var yaw_root:Node3D

@export
var pitch_root:Node3D

var team_asset:Node3D

func aim_at(world_location:Vector3) -> void:
	# TODO:
	pass
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> YawPitchAimingComponent:
	return Components.get_component(ComponentName, node, required) as YawPitchAimingComponent
		
func _enter_tree() -> void:
	team_asset = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if not team_asset:
		push_error("%s: Not added to tree with a TeamAsset!" % name)
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion
