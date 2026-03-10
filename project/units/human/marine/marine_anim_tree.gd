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

var _completed_first_transition:bool
var _state:State = State.IDLE

var state:State:
	get: return _state
	set(value):
		_state = value
		
func _ready() -> void:
	state_machine.start(&"Idle")
	state_machine.state_started.connect(_on_state_started)
	state_machine.state_finished.connect(_on_state_finished)
	
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

func _on_state_started(state_name: StringName) -> void:
	if _completed_first_transition:
		if state_name in anim_state_mappings:
			var new_state:State = anim_state_mappings[state_name]
			state = new_state

func _on_state_finished(state_name: StringName) -> void:
	if state_name in anim_state_mappings:
		_completed_first_transition = true
