class_name HealthStat extends Node

signal health_changed(previous_health:float, current_health:float)
signal took_damage(damage_params:DamageParameters)
signal died(damage_params:DamageParameters)

@export var max_health:float = 1000.0

var is_alive:bool:
	get: return health > 0

var is_dead:bool:
	get: return not is_alive
	
## The current health, set to non-zero to start with that health instead of max
var _health:float = 0.0

@export
var health: float:
	get: return _health 
	set(value):
		var original_health:float = _health
		_health = clampf(value, 0.0, max_health)
		if not is_equal_approx(_health, original_health):
			health_changed.emit(original_health, _health)
	
var health_fraction:float:
	get: return health / max_health

static func get_component(node: Node, required:bool = true) -> HealthStat:
	return Components.get_component(Components.Health, node, required) as HealthStat
		
func on_damage(damage_params:DamageParameters) -> void:
	var orig_health := health
	health = health - damage_params.damage
	var actual_damage:float = orig_health - health
	
	if is_zero_approx(actual_damage):
		return
	
	if not is_equal_approx(actual_damage, damage_params.damage):
		damage_params = damage_params.duplicate()
		damage_params.damage = actual_damage
		
	took_damage.emit(damage_params)
	if is_dead:
		died.emit(damage_params)

## Attempts to connect the callback to the died signal of a HealthStat child node
## Expects a callback with no arguments
## Returns true if HealthStat died signal connected and false if it fell back to tree_exited
## In all cases a signal will be connected for when the node is considered "dead"
## The return result can be used as a guard for warning logging if a HealthStat was expected
static func connect_died_signal(node: Node, callback:Callable) -> bool:
	var health_stat:HealthStat = Components.get_component(Components.Health, node)
	if health_stat:
		callback = callback.unbind(1)
		if not health_stat.died.is_connected(callback):
			health_stat.died.connect(callback)
		else:
			push_warning("connect_died_signal: node=%s with HealthStat=%s is already connected to %s"\
				% [node.name, health_stat.name, callback])
		return true

	node.tree_exited.connect(callback)
	return false
	
func _enter_tree() -> void:
	Components.add_component(Components.Health, self)
	
func _exit_tree() -> void:
	Components.remove_component(Components.Health, self)
	
func _ready() -> void:
	if _health <= 0.0:
		_health = max_health
	Groups.set_scene_root_flag(self, Groups.Damageable)
