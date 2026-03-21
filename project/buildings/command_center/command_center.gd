class_name CommandCenter extends StaticBody3D

@warning_ignore_start("unused_signal")
signal died(damage_params:DamageParameters)
signal damaged(damage_params:DamageParameters)

@onready var health_stat: HealthStat = %HealthStat
@onready var team_comp:TeamComponent = %TeamComponent
@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI

var _aabb:AABB

var heath:HealthStat:
	get: return health_stat
	
@export
var team:int:
	set(value):
		team = value
		if team_comp:
			team_comp.team = team
	
func _ready() -> void:
	_aabb = Collisions.calculate_aabb(self)
	team_comp.team = team
	
func _die(damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	died.emit(damage_params)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(damage_params: DamageParameters) -> void:
	if health_stat.is_dead:
		_die(damage_params)

## Gets an AABB representing the bounds of the structure
func get_bounds() -> AABB:
	return transform * _aabb

func _update_render(in_visible: bool) -> void:
	visual_root.visible = in_visible
	ui.visible = in_visible
