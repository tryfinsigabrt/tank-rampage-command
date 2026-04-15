class_name DamageEmitter extends Node

enum DamageFalloffType
{
	Constant,
	Linear,
	InverseSquare
}

## Controls how signals are emitted when damage is calculated
enum DamageReportingType
{
	## Only report damageable nodes
	Damageable_Only,
	## Report all nodes, but precision splash damage only for damageable
	Damageable_Precise,
	## Reports precise splash damage for all nodes (Potentially poor performance)
	All_Precise
}

@export var damage_falloff_type: DamageFalloffType = DamageFalloffType.Linear

@export var min_falloff_distance: float = 10
@export var max_falloff_distance: float = 60

@export var min_damage: float = 50
@export var max_damage: float = 500

@export var damage_reporting_type: DamageReportingType = DamageReportingType.Damageable_Only

var _sweep_shape:RID

func _enter_tree() -> void:
	if not _sweep_shape:
		_sweep_shape = PhysicsServer3D.sphere_shape_create()
	
func _exit_tree() -> void:
	if _sweep_shape:
		PhysicsServer3D.free_rid(_sweep_shape)
		_sweep_shape = RID()

## Cause damage from the given incident point and an optional damage_filter that can filter out swept colliders
## By default all colliders matching the sweep mask are included	
func damage(incident_damage_params:DamageParameters, damage_filter:Callable = Callable()) -> void:
	if not damage_filter:
		damage_filter = func(_collider:Node3D) -> bool:
			return true
			
	# Calculate initial damage point
	var initial_target:Node3D = incident_damage_params.target_object
	var hit_position:Vector3 = incident_damage_params.contact_point
	var amount:float = _calculate_damage(initial_target, hit_position, hit_position) \
		* incident_damage_params.damage_multiplier
	
	incident_damage_params.damage = amount
	
	# Maps a processed collider node to an array of its group children (for later calculation)
	var processed_nodes:Dictionary[Node, Array]
	var results: Array[DamageParameters]
	
	if amount > 0:
		processed_nodes[initial_target] = _get_damageables(initial_target)
		# Make sure that we only report damageable nodes if requested (Array not empty/truthy)
		if processed_nodes[initial_target] or damage_reporting_type != DamageReportingType.Damageable_Only:
			results.push_back(incident_damage_params)
		
		if max_falloff_distance > 0:
			# Do a sweep for additional units to damage
			var splash_damage_results: Array[Dictionary] = _damage_sweep(incident_damage_params)
			for result in splash_damage_results:
				var collider:Node3D = result["collider"] as Node3D
				if(!is_instance_valid(collider)):
					push_warning("weapon(" + name + " damage overlapped with non-Node3D" +  result["collider"].name)
					continue
				if damage_filter.call(collider) and not collider in processed_nodes:
					var damageable_nodes:Array[Node] = _get_damageables(collider)
					processed_nodes[collider] = damageable_nodes
					if damage_reporting_type == DamageReportingType.Damageable_Only and not damageable_nodes:
						amount = 0.0
					else:
						var contact_position:Vector3
						if damage_reporting_type == DamageReportingType.All_Precise or damageable_nodes:
							contact_position = _get_contact_position(collider, hit_position)
						else:
							contact_position = collider.global_position
							
						amount = _calculate_damage(collider, contact_position, hit_position)
					if amount > 0:
						var damage_result:DamageParameters = DamageParameters.from_shape_intersect(result, incident_damage_params)
						if damage_result:
							damage_result.damage = amount
							results.push_back(damage_result)
						
	if LogUtils.verbose:
		print_debug("%s: damage: nodes impacted=%d; incident_damage_params=%s" % [name, results.size(), incident_damage_params])
	for result in results:
		emit_damage(result, processed_nodes[result.target_object])

func _damage_sweep(incident_damage_params:DamageParameters) -> Array[Dictionary]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = incident_damage_params.damage_mask
	params.margin = Collisions.default_collision_margin
	params.transform = Transform3D(Basis.IDENTITY, incident_damage_params.contact_point)
	
	# Exclude our units
	var to_exclude:Array[RID] = [incident_damage_params.target_rid]
	if not incident_damage_params.source_damage_allowed and incident_damage_params.source_owner:
		to_exclude.push_back(incident_damage_params.source_owner.get_rid())
		
	params.exclude = to_exclude
	
	PhysicsServer3D.shape_set_data(_sweep_shape, max_falloff_distance)
	params.shape_rid = _sweep_shape
	
	var space_state := get_viewport().world_3d.direct_space_state
	
	return space_state.intersect_shape(params)
	
func emit_damage(damage_params:DamageParameters, damageable_children: Array[Node]) -> void:
	if LogUtils.verbose:
		print_debug("damage=%s" % damage_params)
	SignalBus.on_any_damage.emit(damage_params)
	for damageable in damageable_children:
		damageable.on_damage(damage_params)

static func _get_damageables(collider:Node3D) -> Array[Node]:
	return Groups.get_children_in_group(collider, Groups.Damageable)
	
func _calculate_damage(_target: Node3D, contact_position:Vector3, damage_center:Vector3) -> float:
	return _calculate_point_damage(contact_position, damage_center)

func _calculate_point_damage(impact_point: Vector3, pos:Vector3) -> float:
	var dist := (pos - impact_point).length()
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
			var falloff := _calculate_dist_frac(dist)
			return falloff * falloff * max_damage
		_:
			push_error("Unrecognized damage type: " + str(damage_falloff_type))
			return max_damage
			
func _calculate_dist_frac(dist: float) -> float:
	return  (1.0 - (dist - min_falloff_distance) / (max_falloff_distance - min_falloff_distance))
	
func _get_contact_position(collider:Node3D, point:Vector3) -> Vector3:
	var bounds:Bounds
	if collider.has_method("get_bounds"):
		# Use local bounds to avoid the OBB rotated bounds problem
		var aabb:AABB = collider.get_bounds()
		var bounds_type:Bounds.Type = Bounds.Type.AABB
		
		var bounds_type_raw: Variant = collider.get("bounds_type")
		if bounds_type_raw != null:
			bounds_type = bounds_type_raw as Bounds.Type
		else:
			push_warning("%s: Collider %s does not define a bound_type variable for AABB vs BoundingSphere - AABB defaulted!" % [name, collider.name])	
		bounds = Bounds.new(aabb, bounds_type)
	else:
		push_warning("%s: Collision requested for %s that doesn't have get_bounds method - potentially poor performance" % [name, collider.name])
		bounds = Bounds.new(Collisions.calculate_aabb(collider))

	# bounds is local bounds so must transform point into collider space
	var point_local:Vector3 = collider.to_local(point)
	var closest_point_local:Vector3 = bounds.closest_point_to(point_local)
	var closest_point:Vector3 = collider.to_global(closest_point_local)
	
	return closest_point
