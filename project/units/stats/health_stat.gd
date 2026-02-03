class_name HealthStat extends Node

## TODO: There will be a separate 3D UI Node that will connect to this signal to update the health bar
signal health_changed(previous_health:float, current_health:float)
signal took_damage(damage_params:DamageParameters)

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
		
func on_damage(damage_params:DamageParameters) -> void:
	var orig_health = health
	health = health - damage_params.damage
	var actual_damage:float = orig_health - health
	
	if not is_equal_approx(actual_damage, damage_params.damage):
		damage_params = damage_params.duplicate()
		damage_params.damage = actual_damage
		
	took_damage.emit(damage_params)

func _ready() -> void:
	if _health <= 0.0:
		_health = max_health
