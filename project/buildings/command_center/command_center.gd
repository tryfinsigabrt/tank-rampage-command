class_name CommandCenter extends StaticBody3D

@onready var health_stat: HealthStat = %HealthStat
@onready var team_component:TeamComponent = %TeamComponent
@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI

var _aabb:AABB

var _changed_to_visible:bool

var heath:HealthStat:
	get: return health_stat
	
@export
var team:int:
	set(value):
		team = value
		if team_component:
			team_component.team = team
	
func _ready() -> void:
	_aabb = Collisions.calculate_aabb(self)
	team_component.team = team
	SignalBus.register_building(self)
	
func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass

## Gets an AABB representing the bounds of the structure
func get_bounds() -> AABB:
	return transform * _aabb

func _update_render(in_visible: bool) -> void:
	# For now, once we see a building we keep it visible
	# There is a chance the team could move/destroy own buildings but unlikely
	# and buildings are not like units in that once visible they should be visible in state last seen
	if not in_visible and _changed_to_visible:
		return
		
	if in_visible:
		_changed_to_visible = true
		
	visual_root.visible = in_visible
	ui.visible = in_visible
