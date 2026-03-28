@abstract
class_name Building extends StaticBody3D

var _aabb:AABB
var _changed_to_visible:bool
	
@export
var health_stat:HealthStat

@export
var team_component:TeamComponent
		
@export
var attributes:TeamAssetAttributes

@export
var bounds_type: Bounds.Type = Bounds.Type.AABB

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
	
	assert(team_component, "%s: TeamComponent not set!" % name)
	if team_component:
		team_component.update_render.connect(_update_render)
	assert(health_stat, "%s: HealthStat not set!" % name)

#region Abstract/Hook methods

@abstract
func _do_update_render(in_visible:bool) -> void

#endregion

## Gets an AABB representing the bounds of the structure in local space
func get_bounds() -> AABB:
	return _aabb

## Gets the AABB representing the bounds of the structure in global space
func get_global_bounds() -> AABB:
	return global_transform * _aabb

func _update_render(in_visible: bool) -> void:
	# For now, once we see a building we keep it visible
	# There is a chance the team could move/destroy own buildings but unlikely
	# and buildings are not like units in that once visible they should be visible in state last seen
	if not in_visible and _changed_to_visible:
		return
		
	if in_visible:
		_changed_to_visible = true
		
	_do_update_render(in_visible)
