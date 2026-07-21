class_name TurretStructure extends DefensiveStructure

@onready var targeting_component: WeaponTargetingComponent = %WeaponTargetingComponent
@onready var weapon: Weapon = %Weapon
	
func _ready() -> void:
	super()
	targeting_component.add_weapon.call_deferred(1, weapon)
	
func _do_update_render(in_visible:bool) -> void:
	visible = in_visible

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass
