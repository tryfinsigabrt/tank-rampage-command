## Visibility scanner for AI to replicate the fog of war vision system
## This is only added if fow enabled
class_name AiUnitVision extends Area3D

var _unit:Unit
var _vision_counts:Dictionary[int,int] = {}

@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	_unit = Groups.get_parent_in_group(self, Groups.Unit)
	if not _unit:
		push_error("%s: Unit vision not added to a unit hierarchy: " % name)
		queue_free()
		return
	
	
	# Set radius to unit vision radius
	collision.shape.radius = _unit.vision

func _on_body_entered(body: Node3D) -> void:
	_update_visibility(body, 1)
	
func _on_body_exited(body: Node3D) -> void:
	_update_visibility(body, -1)

func _update_visibility(body: Node3D, diff:int) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
	# Exclude units on same team as always can see these - including ourselves
	if unit == _unit or unit.on_same_team(_unit):
		return
		
	var id:int = unit.get_instance_id()
	var updated_count:int = _vision_counts.get(id, 0) + diff
	if updated_count > 0:
		_vision_counts[id] = updated_count
		# Newly visible
		if updated_count == 1:
			print_debug("%s: body=%s is visible to %s" % [name, body.name, _unit.name])
			unit.set_visible_to(_unit.team, true)
	else:
		_vision_counts.erase(id)
		print_debug("%s: body=%s no longer visible to %s" % [name, body.name, _unit.name])
		unit.set_visible_to(_unit.team, false)
