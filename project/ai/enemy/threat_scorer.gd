class_name ThreatScorer extends Node

@export
var threat_score_threshold:float = 0.5

@export
var ideal_distance:float = 300.0

#@export
#var max_distance:float = 1500.0

var _ideal_distance_sq:float
#var _max_distance_sq:float

func _ready() -> void:
	_ideal_distance_sq = ideal_distance * ideal_distance
	#_max_distance_sq = max_distance * max_distance
	
func get_visible_threat_units(units: Array[UnitData], position:Vector3) -> Array[UnitScore]:
	var matches:Array[UnitScore]
	if not units:
		return matches
	
	var max_score:float = 0.0
	
	# TODO: Placeholder Utility AI - use real utility AI system to score and filter candidates
	for unit_data in units:
		if unit_data.valid and unit_data.visible:
			var score:float = unit_data.unit.global_position.distance_squared_to(position)
			#if score > _max_distance_sq:
				#continue
			score = _ideal_distance_sq / maxf(score, 0.001)
			max_score = maxf(score, max_score)
				
			var entry := UnitScore.new()
			entry.unit = unit_data.unit
			entry.score = score
			matches.push_back(entry)
	
	# Normalize scores
	for entry in matches:
		entry.score = entry.score / max_score
	matches.sort_custom(func(a:UnitScore, b:UnitScore) -> bool: return a.score > b.score)
	
	var remove_index_start:int = -1
	for i in range(matches.size() - 1, -1, -1):
		var entry := matches[i]
		if entry.score < threat_score_threshold:
			remove_index_start = i
			break
			
	# Remove from the removal index start by truncating the array
	if remove_index_start >= 0:
		matches.resize(remove_index_start)
		
	return matches
	
