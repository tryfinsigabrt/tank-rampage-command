extends Node

# Anything within 500 units will automatically get a normalized weight of 1.0
@export_range(0.0, 1e9, 0.01, "or_greater")
var distance_normalizer:float = 1.0

@onready 
var blackboard: EnemyTeamBlackboard = %Blackboard

func _on_avoidance_enemies_changed() -> void:
	var avoidance_enemies = blackboard.avoidance_enemies
	var heading_dict:Dictionary[int, Vector3]
	if avoidance_enemies:
		for unit in blackboard.idle_units:
			heading_dict[unit.get_instance_id()] = _calculate_weighted_avoidance_heading(unit, avoidance_enemies)
	
	blackboard.explore_heading_bias = heading_dict
	
func _calculate_weighted_avoidance_heading(unit:Unit, enemies:Array[Unit]) -> Vector3:
	var total_dist_sq:float = 0.0
	var weighted_heading:Vector3 = Vector3.ZERO
	
	var unit_pos:Vector3 = unit.global_position
	
	for enemy in enemies:
		var enemy_pos:Vector3 = enemy.global_position
		# To unit so we flee away from the enemy
		var to_unit:Vector3 = unit_pos - enemy_pos
		var dist_sq:float = to_unit.length_squared()
		
		# Effectively 1/d^3
		weighted_heading += to_unit / maxf(0.01, dist_sq * dist_sq)
		
		total_dist_sq += dist_sq
	
	# Effectively 1/d * N * c
	weighted_heading *= total_dist_sq * enemies.size() * distance_normalizer
	#print_debug("%s: Weight Length=%f" % [name, weighted_heading.length()])
	
	return weighted_heading
