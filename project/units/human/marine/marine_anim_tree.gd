class_name MarineAnimation extends Node3D

enum State
{
	IDLE,
	RUN,
	SHOOT,
	DEAD
}

@export var anim_state_mappings:Dictionary[StringName, State] = {}

@export
var idle_animation_velocity_threshold:float = 0.001

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine:AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var state_tick: Timer = $StateTick

var _unit:HumanMarineUnit
var _horizontal_speed_sq:float

func _ready() -> void:
	_unit = Groups.get_parent_in_group(self, Groups.Unit)
	if animation_tree.active:
		state_tick.start()

var dead:bool:
	get:
		return _unit.is_dead

var running:bool:
	get:
		if shooting:
			return false
		return _horizontal_speed_sq >= idle_animation_velocity_threshold

var shooting:bool:
	get:
		return _unit.is_shooting

var idle:bool:
	get:
		return not running and not shooting

func _on_screen() -> void:
	animation_tree.active = true
	state_tick.start()

func _off_screen() -> void:
	animation_tree.active = false
	state_tick.stop()

## Add any per frame calculations here
## Signal-driven updates are still the most efficient way but avoids re-calculating everything every frame
func _on_state_tick_timeout() -> void:
	var velocity := _unit.velocity
	_horizontal_speed_sq = Vector2(velocity.x, velocity.z).length_squared()
