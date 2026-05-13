class_name AttackedTrackerComponent extends Node

const ComponentName:StringName = &"AttackedTrackerComponent"

signal attackers_changed

@export
var attack_decay_time:float = 10.0

@onready 
var _expired_timer: Timer = $ExpiredTimer

var _team_asset_root:Node

var _health_comp:HealthStat
var _team_component:TeamComponent
var _ai_vision:AiUnitVision

var _attackers: Array[DamageParameters]
var _attacker_died_callables: Dictionary[int,Callable]

var under_attack:bool:
	get:
		return not _attackers.is_empty()
		
## Returns Vector3.INF if no threats
func get_threat_vector() -> Vector3:	
	if not _attackers:
		return Vector3.INF
	
	var sum:Vector3 = Vector3.ZERO
	
	for attacker in _attackers:
		if is_instance_valid(attacker.source_owner):
			sum += attacker.contact_normal
	
	return sum.normalized()
	
func get_visible_attacker_units() -> Array[Unit]:	
	var units:Array[Unit]
	if not units:
		return units

	var check_visible:bool = GameManager.fog_of_war and is_instance_valid(_ai_vision)
	var visible_units:PackedInt64Array
	if check_visible:
		visible_units = _ai_vision.unit_ids
		
	for entry in _attackers:
		var unit:Unit = entry.source_owner as Unit if is_instance_valid(entry.source_owner) else null
		
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
	
	_expired_timer.wait_time = attack_decay_time
	
func _on_took_damaged(damage_params:DamageParameters) -> void:	
	var source_owner: Unit = damage_params.source_owner as Unit
	if not source_owner:
		return
		
	for i in _attackers.size():
		var entry:DamageParameters = _attackers[i]
		var entry_owner := entry.source_owner
		if is_instance_valid(entry_owner) and entry_owner == source_owner:
			_attackers[i] = damage_params
			return
			
	# No existing entry, push_back
	# Listen for tree exited
	var source_owner_id:int = source_owner.get_instance_id()
	var remove_cb:Callable = func() -> void:
		if _remove_entry(source_owner):
			_attacker_died_callables.erase(source_owner_id)
			attackers_changed.emit()
	
	_attacker_died_callables[source_owner_id] = remove_cb
	source_owner.tree_exiting.connect(remove_cb)
		
	_attackers.push_back(damage_params)
	
	if _expired_timer.is_stopped():
		_expired_timer.wait_time = attack_decay_time
		_expired_timer.start()
		
	attackers_changed.emit()
	
func _expire_entries() -> bool:
	var orig_size:int = _attackers.size()
	if not orig_size:
		return false
		
	var now:float = GameManager.game_timer.time_seconds
	for i in range(_attackers.size() - 1, -1, -1):
		var entry: DamageParameters = _attackers[i]
		var valid:bool = true
		var source_owner := entry.source_owner
		
		if not is_instance_valid(source_owner):
			valid = false
		elif now - entry.timestamp >= attack_decay_time:
			valid = false
			var attacker_id:int = source_owner.get_instance_id()
			var attacker_died_cb:Callable = _attacker_died_callables.get(attacker_id)
			if attacker_died_cb:
				if source_owner.tree_exiting.is_connected(attacker_died_cb):
					source_owner.tree_exiting.disconnect(attacker_died_cb)
				_attacker_died_callables.erase(attacker_id)
		
		if not valid:
			_attackers.remove_at(i)
	
	return _attackers.size() != orig_size

func _remove_entry(source:Node) -> bool:
	var index:int = -1
	for i in _attackers.size():
		var entry_source := _attackers[i].source_owner
		if is_instance_valid(entry_source) and entry_source == source:
			index = i
			break
			
	if index != -1:
		_attackers.remove_at(index)
		return true
	return false
				
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

func _on_expired_timer_timeout() -> void:
	if _expire_entries():
		attackers_changed.emit()
	_schedule_next_timer()

func _schedule_next_timer() -> void:
	if not _attackers:
		return
		
	var now:float = GameManager.game_timer.time_seconds
	
	var min_expiration_time:float = INF
	for attacker in _attackers:
		min_expiration_time = minf(attacker.timestamp, min_expiration_time)
		
	var timer_delay:float = min_expiration_time + attack_decay_time - now
	timer_delay = maxf(timer_delay, 0.01)
	_expired_timer.wait_time = timer_delay
	_expired_timer.start()
