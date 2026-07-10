@abstract
class_name Building extends StaticBody3D

var _aabb:AABB
var _changed_to_visible:bool
	
@export
var health_stat:HealthStat

@export
var team_component:TeamComponent

@export
var manufacturing_component:ManufacturingComponent
		
@export
var attributes:TeamAssetAttributes

@export
var bounds_type: Bounds.Type = Bounds.Type.AABB

@export
var visual_root:Node3D

@export
var ui_root:Node3D

@export
var team:int:
	set(value):
		team = value
		if team_component:
			team_component.team = team

func _ready() -> void:
	if attributes:
		attributes.register_with(self)
		
	_aabb = Collisions.calculate_aabb(self)
	team_component.team = team
	SignalBus.register_building(self)
	
	assert(team_component, "%s: TeamComponent not set!" % name)
	if team_component:
		team_component.update_render.connect(_update_render)
	assert(health_stat, "%s: HealthStat not set!" % name)
	assert(manufacturing_component, "%s: ManufacturingComponent not set!" % name)
	
var global_forward:Vector3:
	get:
		return -_orientation_basis().global_basis.z

var forward:Vector3:
	get:
		return -_orientation_basis().basis.z
		
var global_right:Vector3:
	get:
		return _orientation_basis().global_basis.x

var right:Vector3:
	get:
		return _orientation_basis().basis.x
		
var global_up:Vector3:
	get:
		return _orientation_basis().global_basis.y
		
var up:Vector3:
	get:
		return _orientation_basis().basis.y
		
#region Abstract/Hook methods

func _orientation_basis() -> Node3D:
	return self
	
func _do_update_render(in_visible:bool) -> void:
	visual_root.visible = in_visible
	ui_root.visible = in_visible
	
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
	
