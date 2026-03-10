@tool
extends AnimationPlayer

@export_tool_button("Stop and Reset") var button = stop_and_reset

@export var root_motion_node: Node3D
@export var add_root_motion: bool = false
@export var root_motion_target: Vector3 = Vector3.ZERO ## Relative offset
@export var root_motion_duration: float = 1.0 ## In seconds

@export var force_loop: bool = false ## Use the animation finished signal to loop the animation for animations that don't loop.

var cached_original_position: Vector3
var _dirty_position: bool = false

var root_motion: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play(autoplay)
	seek(randf_range(0.0, get_animation(autoplay).length))
	
	if force_loop && get_animation(autoplay).loop_mode == 0:
		animation_finished.connect(play.unbind(1).bind(autoplay))
	
	if root_motion_node and root_motion_target and add_root_motion:
		cached_original_position = root_motion_node.position
		start_root_motion()
	
func start_root_motion() -> void:
	if root_motion:
		if root_motion.is_running():
			root_motion.kill()
	
	root_motion = create_tween()
	root_motion.tween_property(root_motion_node, ^"position", root_motion_node.position+root_motion_target, root_motion_duration).from_current()
	root_motion.set_loops()
	_dirty_position = true
	
func stop_and_reset() -> void:
	if root_motion:
		if root_motion.is_running():
			root_motion.kill()
	if _dirty_position:
		root_motion_node.position = cached_original_position

func _exit_tree() -> void:
	if _dirty_position:
		root_motion_node.position = cached_original_position
