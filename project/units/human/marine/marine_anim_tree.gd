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

var _unit:HumanMarineUnit

func _ready() -> void:
	_unit = Groups.get_parent_in_group(self, Groups.Unit)

var dead:bool:
	get:
		return _unit.is_dead

var running:bool:
	get:
		if shooting:
			return false
			
		var velocity := _unit.velocity
		var horizontal_speed_sq := Vector2(velocity.x, velocity.z).length_squared()
		return horizontal_speed_sq >= idle_animation_velocity_threshold

var shooting:bool:
	get:
		return _unit.is_shooting

var idle:bool:
	get:
		return not running and not shooting


func _on_screen() -> void:
	animation_tree.active = true


func _off_screen() -> void:
	animation_tree.active = false
