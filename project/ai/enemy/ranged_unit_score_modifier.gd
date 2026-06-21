class_name RangedUnitScoreModifier extends ThreatScoreModifier

var unit:Unit

const DIST_SCORE_CURVE:Curve = preload("res://ai/enemy/range_weapon_dist_score.tres")

var damage_cache:Array[DamageResult]

class DamageResult:
	var bounds:BoundingSphere
	var value:float
	
	func contains(pos:Vector3) -> bool:
		return bounds.contains(pos)
		
func begin() -> void:
	damage_cache.clear()

func end() -> void:
	damage_cache.clear()
		
func get_distance_score(score_data:UnitScore, _position:Vector3) -> float:
	var weapon_range:Vector2 = unit.weapon.ideal_fire_range
	var dist:float = score_data.dist
	
	var range_score:float = inverse_lerp(weapon_range.y, weapon_range.x, dist)
	var score:float = DIST_SCORE_CURVE.sample_baked(range_score)
	return score
	
func get_final_score(score_data:UnitScore, score_components:Dictionary[StringName, float]) -> float:
	# Score damage for weapon at target
	var weapon := unit.weapon
	var target := score_data.threat
	var pos := target.global_position
	
	var damage_result:DamageResult
	for entry in damage_cache:
		if entry.contains(pos):
			damage_result = entry
			break
	
	if not damage_result:
		var damage_parameters := unit.weapon.simulate_fire_at(target, pos)
		var score:float = _score_result(damage_parameters)
		var weapon_min_falloff:float = weapon.damage_emitter.falloff_distance_range.x

		damage_result = DamageResult.new()
		damage_result.value = score
		damage_result.bounds = BoundingSphere.new(pos, weapon_min_falloff)
		damage_cache.push_back(damage_result)
	
	var final_score:float = damage_result.value * 0.6 + score_components[&"dist"] * 0.25 + score_components[&"priority"] * 0.15
	return final_score

func _score_result(damage_parameters: Array[DamageParameters]) -> float:
	var score:float = 0.0
	
	var max_damage:float = unit.weapon.damage_emitter.damage_range.y * 10.0
	
	for param in damage_parameters:
		var damage:float = param.damage
		var team_component:TeamComponent = TeamComponent.get_component(param.target_object, false)
		var sgn:float = -1.0 if team_component and team_component.is_ally_team(unit.team) else 1.0
		score += sgn * damage
	
	score = clampf(remap(score, -max_damage, max_damage, -1.0, 1.0), -1.0, 1.0)
	return score
