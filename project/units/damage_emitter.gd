class_name DamageEmitter extends Node

enum DamageFalloffType
{
	Constant,
	Linear,
	InverseSquare
}

@export var damage_falloff_type: DamageFalloffType = DamageFalloffType.Linear

@export var min_falloff_distance: float = 10
@export var max_falloff_distance: float = 60

@export var min_damage: float = 50
@export var max_damage: float = 500

var _sweep_shape:RID

func _enter_tree() -> void:
	if not _sweep_shape:
		_sweep_shape = PhysicsServer3D.sphere_shape_create()
	
func _exit_tree() -> void:
	if _sweep_shape:
		PhysicsServer3D.free_rid(_sweep_shape)
		_sweep_shape = RID()
	
func damage(incident_damage_params:DamageParameters) -> void:
	# Calculate initial damage point
	var initial_target:Node3D = incident_damage_params.target_object
	var hit_position:Vector3 = incident_damage_params.contact_point
	var amount:float = _calculate_damage(initial_target, hit_position, hit_position)
	incident_damage_params.damage = amount
	
	var processed_nodes:Dictionary[Node, bool] = {}
	var results: Array[DamageParameters]
	
	processed_nodes[initial_target] = true

	if amount > 0:
		results.push_back(incident_damage_params)
		if max_falloff_distance > 0:
			# Do a sweep for additional units to damage
			var splash_damage_results: Array[Dictionary] = _damage_sweep(incident_damage_params)
			for result in splash_damage_results:
				var collider:Node3D = result["collider"] as Node3D
				if(!is_instance_valid(collider)):
					push_warning("weapon(" + name + " damage overlapped with non-Node3D" +  result["collider"].name)
					continue
				if not collider in processed_nodes:
					processed_nodes[collider] = true
					amount = _calculate_damage(collider, collider.global_position, hit_position)
					if amount > 0:
						var damage_result:DamageParameters = DamageParameters.from_shape_intersect(result, incident_damage_params)
						damage_result.damage = amount
						results.push_back(damage_result)
						
	if OS.is_debug_build():
		print_debug("%s: damage: nodes impacted=%d; incident_damage_params=%s" % [name, results.size(), incident_damage_params])
	for result in results:
		emit_damage(result)

func _damage_sweep(incident_damage_params:DamageParameters) -> Array[Dictionary]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = incident_damage_params.damage_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, incident_damage_params.contact_point)
	# Exclude our units
	var to_exclude:Array[RID] = [incident_damage_params.target_rid]
	if not incident_damage_params.source_damage_allowed and incident_damage_params.source_unit:
		to_exclude.push_back(incident_damage_params.source_unit.get_rid())
		
	params.exclude = to_exclude
	
	PhysicsServer3D.shape_set_data(_sweep_shape, max_falloff_distance)
	params.shape_rid = _sweep_shape
	
	var space_state := get_viewport().world_3d.direct_space_state
	
	return space_state.intersect_shape(params)
	
func emit_damage(damage_params:DamageParameters) -> void:
	if OS.is_debug_build():
		print_debug("damage=%s" % damage_params)
	SignalBus.on_any_damage.emit(damage_params)
	for damageable in Groups.get_children_in_group(damage_params.target_object, Groups.Damageable):
		damageable.on_damage(damage_params)
		
func _calculate_damage(_target: Node3D, contact_position:Vector3, damage_center:Vector3) -> float:
	return _calculate_point_damage(contact_position, damage_center)

func _calculate_point_damage(impact_point: Vector3, pos:Vector3) -> float:
	var dist = (pos - impact_point).length()
	if dist >= max_falloff_distance:
		return 0.0
	if dist <= min_falloff_distance:
		return max_damage
	
	match damage_falloff_type:
		DamageFalloffType.Constant:
			return max_damage
		DamageFalloffType.Linear:
			return _calculate_dist_frac(dist) * max_damage
		DamageFalloffType.InverseSquare:
			var falloff = _calculate_dist_frac(dist)
			return falloff * falloff * max_damage
		_:
			push_error("Unrecognized damage type: " + str(damage_falloff_type))
			return max_damage
			
func _calculate_dist_frac(dist: float):
	return  (1.0 - (dist - min_falloff_distance) / (max_falloff_distance - min_falloff_distance))
	
