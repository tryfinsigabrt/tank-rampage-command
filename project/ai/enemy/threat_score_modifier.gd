@abstract
class_name ThreatScoreModifier extends Node

func begin() -> void:
	pass

@abstract
func get_distance_score(score_data:UnitScore, position:Vector3) -> float

## Returns a final score given the input scoring data
@abstract
func get_final_score(score_data:UnitScore, score_components:Dictionary[StringName, float]) -> float


func end() -> void:
	pass
