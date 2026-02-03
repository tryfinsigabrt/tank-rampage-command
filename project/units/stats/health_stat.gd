class_name HealthStat extends Node

## TODO: There will be a separate 3D UI Node that will connect to this signal to update the health bar
signal health_changed(previous_health:float, current_health:float)
signal took_damage(damage_params:DamageParameters)

@export var starting_health:float = 100.0
@export var max_health:float = 100.0

@onready var health: float = starting_health: # Must be onready to read export value at runtime
	set(value):
		var original_health:float = health
		health = clampf(value, 0.0, max_health)
		if not is_equal_approx(health, original_health):
			health_changed.emit(original_health, health)
		
func on_damage(damage_params:DamageParameters) -> void:
	var orig_health = health
	health = health - damage_params.damage
	var actual_damage:float = orig_health - health
	
	if not is_equal_approx(actual_damage, damage_params.damage):
		damage_params = damage_params.duplicate()
		damage_params.damage = actual_damage
		
	took_damage.emit(damage_params)
