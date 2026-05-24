class_name RallyPointComponent extends Node

const ComponentName:StringName = &"RallyPointComponent"
const NO_RALLY_POINT_SET:Vector3 = Vector3.INF

signal rally_point_set
signal rally_point_removed

var _manufacturing_component:ManufacturingComponent

var has_rally_point:bool:
	get:
		return rally_point != NO_RALLY_POINT_SET
		
var rally_point:Vector3 = NO_RALLY_POINT_SET:
	set(value):
		rally_point = value
		if is_node_ready():
			if value != NO_RALLY_POINT_SET:
				rally_point_set.emit()
			else:
				rally_point_removed.emit()

func clear_rally_point() -> void:
	rally_point = NO_RALLY_POINT_SET
	
func _ready() -> void:
	var team_asset:Node3D = Groups.get_parent_in_group(self, Groups.TeamAsset) as Node3D
	assert(team_asset,"%s: Component not added to a scene that has a TeamAsset!" % name)
	if not team_asset:
		queue_free()
		return
	_manufacturing_component = ManufacturingComponent.get_component(team_asset)
	if not _manufacturing_component:
		queue_free()
		return
	_manufacturing_component.build_completed.connect(_on_build_completed)

#region Component Registration
static func get_component(node: Node, required:bool = true) -> RallyPointComponent:
	return Components.get_component(ComponentName, node, required) as RallyPointComponent
		
func _enter_tree() -> void:
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion

func _on_build_completed(_resouce:ConstructionResource, node:Node3D) -> void:
	var unit:Unit = node as Unit
	if not unit or not has_rally_point:
		return
		
	print_debug("%s: Sending unit %s to the rally point: %s" % [name, unit.name, rally_point])
	# Issue move and attack to the rally point
	unit.get_or_add_actions().move_and_attack(rally_point)
