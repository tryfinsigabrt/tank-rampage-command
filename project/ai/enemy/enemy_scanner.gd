class_name EnemyScanner extends Node

const max_unit_result_count:int = 256

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

@export
var vision_radius:float = 100.0

var _enemy_sweep_rid:RID
var _visible_enemies:PackedInt64Array
var _new_visible_enemies:PackedInt64Array

func _ready() -> void:
	_enemy_sweep_rid = _create_sweep_shape()
	
func _exit_tree() -> void:
	if _enemy_sweep_rid:
		PhysicsServer3D.free_rid(_enemy_sweep_rid)
	
func _tick() -> void:
	var attention_center:Vector3 = blackboard.team_info.get_average_position()
	blackboard.focus_position = attention_center
	
	var enemy_data:EnemyTeams = blackboard.enemy_teams_info
	enemy_data.mark_all_not_visible()
	
	var enemies:Array[Unit] = sweep_enemies(attention_center)
	_new_visible_enemies.clear()
	
	print_debug("%s: Team %d found %d enemies" % [name, blackboard.team, enemies.size()])
	for enemy in enemies:
		var team_info := enemy_data.get_team(enemy.team)
		if team_info:
			team_info.mark_seen(enemy)
			_new_visible_enemies.push_back(enemy.get_instance_id())
	_new_visible_enemies.sort()
	if _new_visible_enemies != _visible_enemies:
		_visible_enemies = _new_visible_enemies
		blackboard.on_unit_visibility_changed.emit()
		

func _create_sweep_shape() -> RID:
	var shape_rid = PhysicsServer3D.sphere_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, vision_radius)
	
	return shape_rid
	
func sweep_enemies(center:Vector3) -> Array[Unit]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = Collisions.Layers.unit
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, center)
	# Exclude our units
	params.exclude = _to_rids(blackboard.team_info.units)
	params.shape_rid = _enemy_sweep_rid
	
	var space_state := get_viewport().world_3d.direct_space_state
	
	var results: Array[Dictionary] = space_state.intersect_shape(params)
	
	var units:Array[Unit]
	
	for result in results:
		var unit:Unit = result.get("collider") as Unit
		if unit and not unit in units:
			units.push_back(unit)
	
	return units

static func _to_rids(units:Array[Unit]) -> Array[RID]:
	var rids:Array[RID]
	rids.resize(units.size())
	for i in rids.size():
		rids[i] = units[i].get_rid()
	return rids
