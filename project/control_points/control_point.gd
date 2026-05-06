class_name ControlPoint extends Node3D

var _aabb:AABB
var _changed_to_visible:bool

@export
var neutral_color:Color

@export
var owned_color:Color

@export
var enemy_color:Color

@export
var capture_time:float = 10.0

@onready var capture_timer: Timer = %CaptureTimer
@onready var team_component: TeamComponent = %TeamComponent
@onready var sprite: Sprite3D = $VisualRoot/Sprite
@onready var visual_root: Node3D = %VisualRoot
@onready var control_bounds: Area3D = $ControlBounds

var _units_by_team:Dictionary[int, PackedInt64Array] = {}

var owned_team:int:
	get: return team_component.team

var capturing_team:int

var player_team:int

var neutral:bool:
	get:
		return team_component.is_neutral()
var owned:bool:
	get:
		return not neutral
		
# TODO: Add the bounds and AABB functionality to a component called BoundsComponent!
## Gets an AABB representing the bounds of the structure in local space
func get_bounds() -> AABB:
	return _aabb

## Gets the AABB representing the bounds of the structure in global space
func get_global_bounds() -> AABB:
	return global_transform * _aabb
	
func get_units_by_team(team:int, out_units:Array[Unit] = []) -> Array[Unit]:
	if not team in _units_by_team:
		return out_units
	
	var unit_ids: PackedInt64Array = _units_by_team[team]
	for id in unit_ids:
		var unit:Unit = instance_from_id(id)
		if unit:
			out_units.push_back(unit)
	
	return out_units
		
func _ready() -> void:
	capture_timer.wait_time = capture_time
	
	var player:Player = get_tree().get_first_node_in_group(Groups.Player)
	if player and player.player_team:
		player_team = player.player_team.team
	else:
		push_warning("%s: No player node/team in scene - cannot determine enemy status" % name)
		
	_assign_ownership_material(team_component.team)

	_aabb = Collisions.calculate_aabb(control_bounds)
	team_component.update_render.connect(_update_render)
	
	SignalBus.register_control_point(self)
	
func _assign_ownership_material(team:int) -> void:
	var color:Color
	
	if team <= 0:
		color = neutral_color
	elif player_team > 0 and player_team != team:
		color = enemy_color
	else:
		color = owned_color
		
	sprite.modulate = color
	
func _on_control_bounds_body_entered(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return
	
	var team:int = unit.team
	var team_units:PackedInt64Array = _units_by_team.get(team, PackedInt64Array())
	
	var id:int = unit.get_instance_id()
	team_units.push_back(id)
	_units_by_team[team] = team_units
	
	print_debug("%s: Unit %s on team %d entered control point" % [name, unit.name, team])
	
	if team_component.is_ally_team(team):
		return
		
	if not is_constested():
		_capture_or_resume(team)
	elif is_being_captured():
		_contested_capture()

func _contested_capture() -> void:
	# If contested then halt capture timer
	capture_timer.paused = true

func _resume_capture() -> void:
	capture_timer.paused = false

func _capture_or_resume(team:int) -> void:
	if is_being_captured():
		if capturing_team == team:
			if capture_timer.paused:
				_resume_capture()
		elif neutral or team_component.is_enemy_team(team):
			# Changing capturing teams
			_capture(team)
	elif neutral or team_component.is_enemy_team(team):
		_capture(team)
		
func _capture(new_capturing_team:int) -> void:
	print_debug("%s: Begin capture for team %d" % [name, new_capturing_team])
	capturing_team = new_capturing_team
	capture_timer.paused = false
	capture_timer.start()
	
func is_constested() -> bool:
	return _units_by_team.size() > 1
	
func is_being_captured() -> bool:
	return capturing_team and not capture_timer.is_stopped()
	
func _on_control_bounds_body_exited(body: Node3D) -> void:
	var unit:Unit = body as Unit
	if not unit:
		return

	var team:int = unit.team
	print_debug("%s: Unit %s on team %d exited control point" % [name, unit.name, team])

	var team_units:PackedInt64Array = _units_by_team[team]
	var id:int = unit.get_instance_id()

	var was_contested:bool = is_constested()
	team_units.erase(id)
	
	if team_units.is_empty():
		_units_by_team.erase(team)
	else:
		return
		
	if capturing_team == team:
		_stop_capture()
		
	if _units_by_team.size() == 1 and was_contested:
		var new_team:int = _units_by_team.keys().front()
		_capture_or_resume(new_team)
		
func _stop_capture() -> void:
	print_debug("%s: team %d stopped capturing" % [name, capturing_team])
	capture_timer.paused = false
	capture_timer.stop()
	capturing_team = 0
	
func _on_capture_timer_timeout() -> void:
	print_debug("%s: Capture timer completed" % [name])
	if neutral:
		team_component.team = capturing_team
		capturing_team = 0
		var new_owner:int = owned_team
		print_debug("%s: Captured by team %d" % [name, new_owner])
		_assign_ownership_material(new_owner)
		SignalBus.on_control_point_captured.emit(new_owner, self)
	else:
		# Turn neutral and now need to capture
		var previous_owner := team_component.team
		team_component.team = 0
		print_debug("%s: Neutralized by team %d" % [name, owned_team])
		_assign_ownership_material(0)
		
		# Start timer again
		capture_timer.start()
		
		SignalBus.on_control_point_neutralized.emit(previous_owner, self)

# TODO: Duplicated with buildings
func _update_render(in_visible: bool) -> void:
	# For now, once we see a building we keep it visible
	# There is a chance the team could move/destroy own buildings but unlikely
	# and buildings are not like units in that once visible they should be visible in state last seen
	if not in_visible and _changed_to_visible:
		return
		
	if in_visible:
		_changed_to_visible = true
	
	visual_root.visible = in_visible
	#ui.visible = in_visible
