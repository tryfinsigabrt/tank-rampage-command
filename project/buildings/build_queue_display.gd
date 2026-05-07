class_name BuildQueue extends Node3D

@export
var manufacturing_component:ManufacturingComponent

@onready var sprite: Sprite3D = %Sprite01
@onready var sprite_container: Node3D = %SpriteContainer
@onready var display_tick: Timer = %DisplayTick

@export
var sprite_size:float = 1.0

var _prototype_material:ShaderMaterial
var _queue_count:int

var _sprites:Array[Sprite3D]

var _build_start_time:float = -1.0
var _active_build_resource:ConstructionResource

func _ready() -> void:
	_prototype_material = sprite.material_override as ShaderMaterial
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
	sprite.pixel_size = sprite_size / sprite.texture.get_width()
	_sprites = [sprite]

func _on_build_queued(resource:ConstructionResource) -> void:
	_queue_count += 1
	_create_sprite(resource)
	
	#print("QUEUED: %d" % _queue_count)
		
func _on_build_started(resource:ConstructionResource) -> void:
	_build_start_time = GameManager.game_timer.time_seconds
	_active_build_resource = resource
	display_tick.start()
	
	#print("STARTED: %d" % _queue_count)

func _on_build_completed(_resource:ConstructionResource, _node:Node3D) -> void:
	_queue_count -= 1
	display_tick.stop()
		
	_active_build_resource = null
	_build_start_time = -1.0
	
	# Shift over all materials
	for i in range(1, _queue_count + 1):
		_sprites[i - 1].material_override = _sprites[i].material_override
		
	_sprites[_queue_count].visible = false
	
	#print("COMPLETED: %d" % _queue_count)

func _create_sprite(resource:ConstructionResource) -> void:
	var new_sprite:Sprite3D
	if _queue_count <= _sprites.size():
		new_sprite = _sprites[_queue_count - 1]
	else:
		new_sprite = sprite.duplicate()
		new_sprite.name = "Sprite%02d" % [_sprites.size() + 1]
		var pos: Vector3 = _sprites.back().position
		pos.x += sprite_size * scale.x
		new_sprite.position = pos
		
		_sprites.push_back(new_sprite)
		sprite_container.add_child(new_sprite)

	var material:ShaderMaterial = _prototype_material.duplicate()
	new_sprite.material_override = material
	new_sprite.visible = true
	material.set_shader_parameter(&"image", resource.icon)
	material.set_shader_parameter(&"progress", 0.0)
		
func _tick() -> void:
	var current_time:float = GameManager.game_timer.time_seconds
	var progress:float = (current_time - _build_start_time ) / _active_build_resource.time
	var active_sprite: Sprite3D = _sprites.front()
	var active_material := active_sprite.material_override as ShaderMaterial
	if not active_material:
		return
	
	#print("ACTIVE_SPRITE:%s(%d):%f" % [active_sprite.name, _queue_count, progress])
	active_material.set_shader_parameter(&"progress", progress)
