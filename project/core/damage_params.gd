class_name DamageParameters

var damage_mask:int

## The object collided
var target_object:Node3D

## RID of physics object collision
var target_rid:RID

var target_collider_id:int

var source_weapon:Weapon

var source_unit:Unit

var damage:float

var contact_point:Vector3

var contact_normal:Vector3

var is_direct_hit:bool
var source_damage_allowed:bool

func _to_string() -> String:
	return "target=%s; weapon=%s; source=%s; damage=%f; contact=%s; normal=%s; is_direct=%s" % [target_object.name, source_weapon.name, source_unit, damage, contact_point, contact_normal, is_direct_hit]
	
func duplicate() -> DamageParameters:
	var result := _duplicate_from_prototype()
	result.target_object = target_object
	result.target_collider_id = target_collider_id
	result.damage = damage
	result.contact_point = contact_point
	result.contact_normal = contact_normal
	result.is_direct_hit = is_direct_hit
	
	return result
	
func _duplicate_from_prototype() -> DamageParameters:
	var result := DamageParameters.new()
	result.damage_mask = damage_mask
	result.source_damage_allowed = source_damage_allowed
	result.source_weapon = source_weapon
	result.source_unit = source_unit
	
	return result
	
static func from_ray_intersect(results: Dictionary, prototype:DamageParameters = null) -> DamageParameters:
	if not results:
		return null

	var params := prototype._duplicate_from_prototype() if prototype else DamageParameters.new()
	
	params.target_object = results["collider"]
	params.target_collider_id = results["collider_id"]
	params.contact_point = results["position"]
	params.contact_normal = results["normal"]
	params.target_rid = results["rid"]
	params.is_direct_hit = true

	return params

static func from_shape_intersect(results: Dictionary, prototype:DamageParameters = null) -> DamageParameters:
	if not results:
		return null

	var params := prototype._duplicate_from_prototype() if prototype else DamageParameters.new()
	
	params.target_object = results["collider"]
	params.target_collider_id = results["collider_id"]
	params.contact_point = params.target_object.global_position
	params.target_rid = results["rid"]
	params.is_direct_hit = false

	return params
