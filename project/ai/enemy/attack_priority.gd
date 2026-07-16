class_name AttackPriority

var target:Node3D
var target_id:int
var weight:float = 1.0

var valid:bool:
	get:
		return is_instance_valid(target)
		
func _init(in_target:Node3D) -> void:
	target = in_target
	target_id = in_target.get_instance_id()
		
static func create_target_id_map(priorities: Array[AttackPriority]) -> Dictionary[int, AttackPriority]:
	var attack_priority_map:Dictionary[int, AttackPriority]
	for priority in priorities:
		var node:Node3D = priority.target
		if is_instance_valid(node):
			attack_priority_map[node.get_instance_id()] = priority
	return attack_priority_map
