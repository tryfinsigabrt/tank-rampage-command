class_name BuildQueue extends Node3D

@export
var manufacturing_component:ManufacturingComponent

@onready var sprite: Sprite3D = %Sprite1
@onready var sprite_container: Node3D = %SpriteContainer
@onready var display_tick: Timer = %DisplayTick

@export
var sprite_size:float = 1.0

var _material_by_type:Dictionary[ConstructionResource.Type, ShaderMaterial] = {}
var _prototype_material:ShaderMaterial
var _total_build_count:int
var _active_build_count:int

var _sprites:Array[Sprite3D]
var _active_sprite:Sprite3D

var _build_start_time:float = -1.0
var _active_build_resource:ConstructionResource

func _ready() -> void:
	_prototype_material = sprite.material_overlay as ShaderMaterial
	if not _prototype_material:
		assert(false, "%s: Material on %s is not a ShaderMaterial" % [name, sprite.name])
		queue_free()
		return
	if not manufacturing_component:
		assert(false, "%s: manufacturing_component not set!" % name)
		queue_free()
		return
	
	manufacturing_component.build_queued.connect(_on_build_queued)
	manufacturing_component.build_started.connect(_on_build_started)
	manufacturing_component.build_completed.connect(_on_build_completed)
	
	sprite.visible = false
	_sprites = [sprite]

func _on_build_queued(resource:ConstructionResource) -> void:
	_total_build_count += 1
	_active_build_count += 1
	_create_sprite(resource)
		
func _on_build_started(resource:ConstructionResource) -> void:
	_build_start_time = GameManager.game_timer.time_seconds
	_active_build_resource = resource
	display_tick.start()
	
	# Circular buffer logic
	var active_index:int = (_total_build_count - _active_build_count) % _sprites.size()
	_active_sprite = _sprites[active_index]
	# TODO: Need to shift the position visually
	
func _on_build_completed(_resource:ConstructionResource, _node:Node3D) -> void:
	_active_build_count -= 1
	display_tick.stop()
	
	_active_build_resource = null
	_build_start_time = -1.0
	_active_sprite.visible = false
	
	# TODO: Need to shift the positions of the remaining visible ones
	
	if _active_build_count == 0:
		_total_build_count = 0

func _create_sprite(resource:ConstructionResource) -> void:
	var new_sprite:Sprite3D
	if _active_build_count <= _sprites.size():
		new_sprite = _sprites[_total_build_count % _sprites.size()]
	else:
		new_sprite = sprite.duplicate()
		var pos: Vector3 = _sprites.back().position
		pos.x += sprite_size
		new_sprite.position = pos
		
		_sprites.push_back(new_sprite)
		sprite_container.add_child(new_sprite)
		
	var material:ShaderMaterial = _material_by_type.get(resource.type)
	if not material:
		material = _prototype_material.duplicate()
		_material_by_type[resource.type] = material
	
	new_sprite.material = material
	new_sprite.visible = true
	material.set_shader_parameter(&"image", resource.icon)
	material.set_shader_parameter(&"progress", 0.0)
		
func _tick() -> void:
	var current_time:float = GameManager.game_timer.time_seconds
	var progress:float = (current_time - _build_start_time ) / _active_build_resource.time
	
	_active_sprite.material_overlay.set_shader_parameter(&"progress", progress)
