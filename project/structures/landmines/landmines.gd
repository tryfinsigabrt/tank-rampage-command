class_name Landmine extends DefensiveStructure

@onready var visual_root: Node3D = $VisualRoot
@onready var ui: Node3D = %UI
@onready var damage_emitter: DamageEmitter = %DamageEmitter
@onready var area_collision: CollisionShape3D = %AreaCollision
@onready var collision: CollisionShape3D = %Collision
@onready var trigger_area: Area3D = %TriggerArea

@export
var friendly_fire:bool = false

func _ready() -> void:
	super._ready()
	
	# Set area shape based on input collision shape
	area_collision.shape = collision.shape
	
	trigger_area.collision_mask = _update_mask(trigger_area.collision_mask)
	
func _do_update_render(in_visible:bool) -> void:
	visual_root.visible = in_visible
	ui.visible = in_visible

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass

func _update_mask(damage_mask:int) -> int:
	if friendly_fire:
		damage_mask |= Collisions.CompositeMasks.any_unit
	else:
		var enemy_team_mask:int = Collisions.enemy_team_mask(team_component.team)
		damage_mask = MathUtils.update_mask(damage_mask, Collisions.CompositeMasks.any_unit, enemy_team_mask)
	return damage_mask
	
func _on_trigger_area_body_entered(body: Node3D) -> void:
	# only units should be detected
	var unit:Unit = body as Unit
	if not unit:
		return
	print_debug("%s: %s entered" % [name, unit.name])
	
	# Handled by team mask
	#if not _allow_damage(unit):
		#print_debug("%s: Ignoring friendly %s" % [name, unit.name])
		#return
	
	var damage_params:DamageParameters = DamageParameters.new()
	damage_params.contact_point = unit.global_position
	damage_params.contact_normal = unit.get_floor_normal()
	damage_params.damage_mask = collision_mask
	damage_params.source = self
	damage_params.source_owner = self
	damage_params.target_object = unit
	damage_params.source_damage_allowed = false
	damage_params.target_object = unit
	damage_params.target_rid = unit.get_rid()
	
	damage_emitter.damage(damage_params, _allow_damage)
	
	# Self-destruct
	health_stat.die()
	
func _allow_damage(collider: Node3D) -> bool:
	var unit:Unit = collider as Unit
	if not unit:
		return false
	return friendly_fire or unit.team_component.is_enemy(team_component)
