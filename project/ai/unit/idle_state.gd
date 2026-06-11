class_name IdleUnitState extends Node

signal threat_selected(threat:Node3D)

@onready var unit_scanner: UnitScanner = $UnitScanner
@onready var threat_scorer: ThreatScorer = $ThreatScorer

@export
var my_unit:Unit

var enabled:bool:
	set(value):
		if not unit_scanner:
			return
			
		if value:
			unit_scanner.my_asset = my_unit
		unit_scanner.enabled = value
	get:
		return enabled
	
func _on_unit_scanner_threats_detected(threats: Array[Node3D]) -> void:
	var scores := threat_scorer.get_threat_assets(threats, my_unit.global_position)
	if scores:
		threat_selected.emit(scores.front().threat)
