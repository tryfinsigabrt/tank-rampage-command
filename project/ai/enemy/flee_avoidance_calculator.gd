extends Node

@export
var threat_magnitude_v_distance:Curve

@onready 
var blackboard: EnemyTeamBlackboard = %Blackboard

func _ready() -> void:
	if not threat_magnitude_v_distance:
		push_error("%s: Missing threat_magnitude_v_distance curve" % name)
		queue_free()
		
func _on_avoidance_enemies_changed() -> void:
	var avoidance_enemies := blackboard.avoidance_enemies
	var heading_dict:Dictionary[int, Vector3]
	if avoidance_enemies:
		for unit in blackboard.idle_units:
			heading_dict[unit.get_instance_id()] = _calculate_weighted_avoidance_heading(unit, avoidance_enemies)
	
	blackboard.explore_heading_bias = heading_dict
	
func _calculate_weighted_avoidance_heading(unit:Unit, enemies:Array[Unit]) -> Vector3:
	var total_threat_score:float = 0.0
	var cumulative_heading:Vector3 = Vector3.ZERO
	
	var unit_pos:Vector3 = unit.global_position
	
	for enemy in enemies:
		var enemy_pos:Vector3 = enemy.global_position
		# To unit so we flee away from the enemy
		var to_unit:Vector3 = unit_pos - enemy_pos
		var dist:float = to_unit.length()
		
		# Effectively 1/d^2
		cumulative_heading += to_unit / maxf(0.01, dist ** 3)
		
		var firing_range_fract:float = 0.0
		var weapon:Weapon = enemy.weapon
		if weapon:
			firing_range_fract = dist / weapon.ideal_fire_range.y
			
		var threat_score:float = threat_magnitude_v_distance.sample_baked(firing_range_fract)
		total_threat_score += threat_score
	
	var heading:Vector3 = cumulative_heading.normalized()
	var weighted_heading:Vector3 = heading * total_threat_score
	
	#print_debug("%s: Weight Length=%f" % [name, total_threat_score])
	return weighted_heading
