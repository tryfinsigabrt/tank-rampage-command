@tool
class_name MarineAnimation extends Node3D

enum State
{
	IDLE,
	RUN,
	SHOOT,
	DEAD
}

@export var anim_state_mappings:Dictionary[StringName, State] = {}

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine:AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var animation_player: AnimationPlayer = get_node("../VisualRoot/AnimationPlayer")

const LIBRARY_NAME := &"human_marine_anims"
const STATE_TO_TREE_NODE := {
	State.IDLE: &"Idle",
	State.RUN: &"Run",
	State.SHOOT: &"Shoot",
	State.DEAD: &"Dead",
}
const SOURCE_ANIMATION_SCENES := {
	&"Idle": preload("res://units/human/marine/anim-examples/idle.tscn"),
	&"Run": preload("res://units/human/marine/anim-examples/run.tscn"),
	&"Shoot": preload("res://units/human/marine/anim-examples/shoot.tscn"),
	&"Death": preload("res://units/human/marine/anim-examples/death_nonlooping.tscn"),
}


var _state:State = State.IDLE

var state:State:
	get: return _state
	set(value):
		if _state == value:
			return
		_state = value
		if is_node_ready():
			_travel_to_state(value)
		
func _ready() -> void:
	_ensure_animation_library_loaded()
	animation_tree.active = true
	state_machine.state_finished.connect(_on_state_finished)
	_travel_to_state(_state)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_ensure_animation_library_loaded()
	
func idle() -> void:
	state = State.IDLE

func run() -> void:
	if _state != State.DEAD:
		state = State.RUN
	
# TODO: Should be able to shoot while running?
func shoot() -> void:
	if _state != State.DEAD:
		state = State.SHOOT
	
func die() -> void:
	state = State.DEAD

func _ensure_animation_library_loaded() -> void:
	if not is_instance_valid(animation_player):
		return

	animation_player.root_node = NodePath("..")

	var library: AnimationLibrary = _get_or_create_library()
	for animation_name: StringName in SOURCE_ANIMATION_SCENES.keys():
		var existing: Animation = library.get_animation(animation_name) if library.has_animation(animation_name) else null
		if existing != null and existing.get_track_count() > 0:
			continue

		var clip: Animation = _load_animation_from_scene(SOURCE_ANIMATION_SCENES[animation_name], animation_name)
		if clip == null:
			push_warning("%s: Missing source animation '%s'" % [name, animation_name])
			continue

		if library.has_animation(animation_name):
			library.remove_animation(animation_name)
		library.add_animation(animation_name, clip)

func _get_or_create_library() -> AnimationLibrary:
	if animation_player.has_animation_library(LIBRARY_NAME):
		return animation_player.get_animation_library(LIBRARY_NAME)

	var library := AnimationLibrary.new()
	animation_player.add_animation_library(LIBRARY_NAME, library)
	return library

func _load_animation_from_scene(scene: PackedScene, animation_name: StringName) -> Animation:
	var instance := scene.instantiate()
	var source_player: AnimationPlayer = instance.get_node_or_null("AnimationPlayer")
	if source_player == null:
		instance.free()
		return null

	var source_animation: Animation = source_player.get_animation(animation_name)
	var duplicate_animation: Animation = source_animation.duplicate(true) if source_animation != null else null
	instance.free()
	return duplicate_animation

func _travel_to_state(target_state: State) -> void:
	var state_name: StringName = STATE_TO_TREE_NODE[target_state]
	if state_machine.get_current_node() == state_name:
		return
	state_machine.travel(state_name)

func _on_state_finished(state_name: StringName) -> void:
	if state_name == STATE_TO_TREE_NODE[State.SHOOT] and _state == State.SHOOT:
		state = State.IDLE
