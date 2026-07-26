class_name IdleUnitState extends Node

signal threat_selected(threat:Node3D)

@onready var unit_scanner: UnitScanner = $UnitScanner
@onready var threat_scorer: ThreatScorer = $ThreatScorer

@export
var my_unit:Unit

## Range of idle state where the x value is the ideal attack range and the y value is the max auto-attack distance.
## These can differ for ranged units.
@export
var attack_range:Vector2 = Vector2(100.0, 100.0):
	set(value):
		attack_range = value
		
		if not unit_scanner:
			return
		
		_update_scan_radius()

var enabled:bool:
	set(value):
		if not unit_scanner:
			return
		
		enabled = value
		_update_scan_radius()
			
		if value and unit_scanner.my_asset != my_unit:
			unit_scanner.my_asset = my_unit
			threat_scorer.apply_scoring_modifier_for(my_unit)
		unit_scanner.enabled = value
	get:
		return enabled

func _update_scan_radius() -> void:
	if attack_range.y > 0:
		unit_scanner.threshold_distance = attack_range.y
		if attack_range.x > 0:
			threat_scorer.ideal_distance = attack_range.x
		
func _on_unit_scanner_threats_detected(threats: Array[Node3D]) -> void:
	var scores := threat_scorer.get_threat_assets(threats, my_unit.global_position)
	if scores:
		threat_selected.emit(scores.front().threat)
