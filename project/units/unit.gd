## Base class for all units in the game
@abstract
class_name Unit extends CharacterBody3D

@warning_ignore_start("unused_signal")
signal died(damage_params:DamageParameters)
signal damaged(damage_params:DamageParameters)

signal on_entered_world_boundaries(world_boundaries: WorldBoundaries)
signal on_left_world_boundaries(world_boundaries:WorldBoundaries)

@warning_ignore_restore("unused_signal")

enum UnitClass
{
	None,
	Tank,
	Artillery,
	Soldier,
}

static func group_for_class(in_class:UnitClass) -> StringName:
	match in_class:
		UnitClass.Tank: return Groups.Units.Tank
		UnitClass.Artillery: return Groups.Units.Artillery
		UnitClass.Soldier: return Groups.Units.Soldier
		_:
			push_warning("Invalid unit_class=%d" % [in_class])
			return &""

@export_range(1.0, 1e9, 0.1, "or_greater")
var movement_speed:float = 15.0

@export
var team:int:
	set(value):
		if value == team:
			return
		team = value
		if is_node_ready():
			refresh_team_layers()

@export
var unit_class:UnitClass

@export_range(1.0, 1e9, 0.1, "or_greater")
var vision:float = 50.0

var render:bool = true:
	set(value):
		if value == render:
			return
		render = value
		_update_render()

var team_visibility_mask:int
	
var unit_class_group:StringName:
	get:
		return group_for_class(unit_class)
		
var is_moving:bool:
	get: return _is_moving()
	
var is_alive:bool:
	get: return _is_alive()

var is_dead:bool:
	get: return not is_alive
	
var health:HealthStat:
	get: return _get_health_stat()

var _unit_actions:UnitActions

#region Abstracts/Hooks
@abstract
## Provides the screen direction to instruct the unit to move to
func move(input_direction:Vector2, speed_override:float = -1.0) -> void

@abstract
func aim_at(world_location:Vector3) -> void

@abstract
func shoot() -> void

@abstract
func _is_moving() -> bool

## Hides or shows the visual instance
@abstract
func _update_render() -> void

func _is_alive() -> bool:
	return true
	
func _get_health_stat() -> HealthStat:
	return null
	
#endregion

func _ready() -> void:
	SignalBus.register_unit(self)
	refresh_team_layers()
	
#region Teams

func refresh_team_layers() -> void:
	Collisions.apply_team_collision_layer(self, team)
	Visibility.apply_team_collision_layer(self, team)
	if GameManager.fog_of_war:
		set_visible_to(team, true)
	else:
		# Everything visible
		team_visibility_mask = 0xffffffff
	
func on_same_team(unit:Unit) -> bool:
	return unit and unit.team == team
	
func is_on_team(in_team:int) -> bool:
	return team == in_team

static func to_team_mask(in_team:int) -> int:
	return in_team << (in_team - 1)
	
func is_visible_to(in_team:int) -> bool:
	return team_visibility_mask & to_team_mask(in_team)

func set_visible_to(in_team:int, in_visible:bool):
	var team_mask:int = to_team_mask(in_team)
	if in_visible:
		team_visibility_mask |= team_mask
	else:
		team_visibility_mask &= ~team_mask
	
# TODO: Right now don't have concept of allied teams but this leaves that open for future
func is_ally(unit:Unit) -> bool:
	return on_same_team(unit)
	
func is_ally_team(in_team:int) -> bool:
	return is_on_team(in_team)
	
func is_enemy(unit:Unit) -> bool:
	return unit and not is_ally(unit)
	
func is_enemy_team(in_team:int) -> bool:
	return not is_ally_team(in_team)

static func get_all_units_on_team(in_team:int) -> Array[Unit]:
	var nodes: Array[Node] = Engine.get_main_loop().get_nodes_in_group(Groups.Unit)
	var units:Array[Unit] = []
	for node in nodes:
		if node is Unit and node.is_on_team(in_team):
			units.push_back(node)
	return units
	
func get_all_units_on_same_team() -> Array[Unit]:
	return get_all_units_on_team(team)
#endregion
	
#region Unit Classes
static func get_all_units_on_team_and_class(in_team:int, in_class:UnitClass) -> Array[Unit]:
	var nodes: Array[Node] = Engine.get_main_loop().get_nodes_in_group(group_for_class(in_class))
	var units:Array[Unit] = []
	for node in nodes:
		if node is Unit and node.is_on_team(in_team):
			units.push_back(node)
	return units
	
func get_all_units_same_team_and_class() -> Array[Unit]:
	return get_all_units_on_team_and_class(team, unit_class)
	
func is_same_class(unit:Unit) -> bool:
	return unit and unit_class == unit.unit_class
	
#endregion

func _get_unit_actions_scene() -> PackedScene:
	# unit_actions.tscn
	return preload("uid://hxa7arwfl6dn")

func get_or_add_actions() -> UnitActions:
	if is_instance_valid(_unit_actions):
		return _unit_actions
	_unit_actions = _get_unit_actions_scene().instantiate()

	_unit_actions.name = "UnitActions"
	_unit_actions.unit = self

	add_child(_unit_actions)
	return _unit_actions

func get_fire_global_position() -> Vector3:
	return global_position

func get_fire_global_forward() -> Vector3:
	return global_forward

func get_fire_global_right() -> Vector3:
	return global_right

func get_fire_global_up() -> Vector3:
	return global_up
	
func _orientation_basis() -> Node3D:
	return self
	
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
