class_name AttackedTrackerComponent extends Node

signal attackers_changed

@export
var attack_decay_time:float = 10.0

const ComponentName:StringName = &"AttackedTrackerComponent"

var _team_asset_root:Node

var _health_comp:HealthStat
var _team_component:TeamComponent
var _ai_vision:AiUnitVision

var _attackers: Array[DamageParameters]

var under_attack:bool:
	get:
		return not _attackers.is_empty()
		
## Returns Vector3.INF if no threats
func get_threat_vector() -> Vector3:
	_expire_entries()
	
	if not _attackers:
		return Vector3.INF
	
	var sum:Vector3 = Vector3.ZERO
	
	for attacker in _attackers:
		sum += attacker.contact_normal
	
	return sum.normalized()
	
func get_visible_attacker_units() -> Array[Unit]:
	_expire_entries()
	
	var units:Array[Unit]
	if not units:
		return units

	var check_visible:bool = GameManager.fog_of_war and is_instance_valid(_ai_vision)
	var visible_units:PackedInt64Array
	if check_visible:
		visible_units = _ai_vision.unit_ids
		
	for entry in _attackers:
		var unit:Unit = entry.source_owner as Unit
		if not unit or (check_visible and unit.get_instance_id() not in visible_units):
			continue
		units.push_back(unit)
		
	return units
		
func _ready() -> void:
	if not _team_asset_root:
		push_error("%s: AttackerTrackerComponent not added to a team asset hierarchy: " % name)
		queue_free()
		return
	_team_component = Components.get_component(Components.Team, _team_asset_root)
	if not _team_component:
		push_error("%s: AttackerTrackerComponent asset %s has no team_component!" % [name, _team_asset_root.name])
		queue_free()
		return
	_health_comp = Components.get_component(Components.Health, _team_asset_root)
	if not _health_comp:
		push_error("%s:  AttackerTrackerComponent asset %s has no health stat!" % [name, _team_asset_root.name])
		queue_free()
		return
		
	_health_comp.took_damage.connect(_on_took_damaged)
	# If AI Unit vision added and FOW then only list out known attackers that are visible
	_ai_vision = AiUnitVision.get_component(_team_asset_root, false)
	
func _on_took_damaged(damage_params:DamageParameters) -> void:
	_expire_entries()
	
	var source_owner: Unit = damage_params.source_owner as Unit
	if not source_owner:
		return
		
	for i in _attackers.size():
		var entry:DamageParameters = _attackers[i]
		# == is safe here as we already expired invalid entries
		if entry.source_owner == source_owner:
			_attackers[i] = damage_params
			return
	# No existing entry, push_back
	_attackers.push_back(damage_params)	
	attackers_changed.emit()
	
func _expire_entries() -> void:
	var orig_size:int = _attackers.size()
	if not orig_size:
		return
		
	var now:float = GameManager.game_timer.time_seconds
	for i in range(_attackers.size() - 1, -1, -1):
		var entry: DamageParameters = _attackers[i]
		var valid:bool = true
		if not is_instance_valid(entry.source_owner):
			valid = false
		elif now - entry.timestamp > attack_decay_time:
			valid = false
		
		if not valid:
			_attackers.remove_at(i)
	
	if _attackers.size() != orig_size:
		attackers_changed.emit.call_deferred()
		
#region Component Registration
static func get_component(node: Node, required:bool = true) -> AttackedTrackerComponent:
	return Components.get_component(ComponentName, node, required) as AttackedTrackerComponent
		
func _enter_tree() -> void:
	_team_asset_root = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if _team_asset_root:
		Components.add_component(ComponentName, self, _team_asset_root)

func _exit_tree() -> void:
	if _team_asset_root:
		Components.remove_component(ComponentName, self, _team_asset_root)
	if _attackers:
		_attackers.clear()
		attackers_changed.emit()
#endregion
