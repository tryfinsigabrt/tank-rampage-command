extends CPUParticles3D

@export var heading_offset_degrees:float = 90.0

# only emit particles if we are moving
var prev_pos:Vector2

func _ready() -> void:
	prev_pos = MathUtils.grid_vector(global_position)
	emitting = false
	_update_heading()

func _tick() -> void:
	if not is_visible_in_tree():
		emitting = false
		return
		
	var current_position := MathUtils.grid_vector(global_position)
	var moving:bool = not current_position.is_equal_approx(prev_pos)
	
	if moving:
		_update_heading()
		
	emitting = moving
	prev_pos = current_position

func _update_heading() -> void:
	global_rotation.y = get_parent_node_3d().global_rotation.y + deg_to_rad(heading_offset_degrees)
