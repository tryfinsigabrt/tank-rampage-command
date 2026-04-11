class_name UtilityThreatHandler extends UtilityAIHandler

const UTILITY_CALCULATOR_ID:StringName = &"UtilityCalculator"

@export
var draw_duration:float = 3.0

var _index:int
var _chosen_option:UtilityAIOption
var _scores:Dictionary[UtilityAIOption, float]

func supports(utility_node_name:StringName) -> bool:
	return utility_node_name == UTILITY_CALCULATOR_ID
	
func start(_team:int, index:int, scores: Dictionary[UtilityAIOption, float], chosen_option:UtilityAIOption) -> void:
	_index = index
	_scores = scores
	_chosen_option = chosen_option
	
func option_action_to_string(option:UtilityAIOption) -> String:
	return option.action

func option_context_to_string(option:UtilityAIOption) -> String:
	var context:UnitThreatContext = option.context

	var context_header:String = "CONTEXT(%d): size=%.1f ec=%d fc=%d distance=%.1f estr=%.1f fstr=%.1f" \
		% [_index, context.threat_cluster.size, context.threat_size, context.assist_size, context.distance,
		 context.threat_cluster_strength, context.assist_cluster_strength]
	return context_header
	
func finish() -> void:
	var d_config := DebugDraw3D.new_scoped_config()
	#d_config.set_text_fixed_size(true)
	d_config.set_text_outline_size(4)
	#d_config.set_no_depth_test(true)
	d_config.set_thickness(0.5)
	
	var context:UnitThreatContext = _chosen_option.context
	# Draw also in world
	var cluster_center:Vector2 = context.threat_cluster.center
	var y:float = context.threat_cluster.units.front().global_position.y
	var center:Vector3 = Vector3(cluster_center.x, y, cluster_center.y)
	DebugDraw3D.draw_sphere(center, context.threat_cluster.size, _color_from_index(), draw_duration)
	
	# Doesn't work with FOW as the FOW quad post-process shader gets drawn over the label
	DebugDraw3D.draw_text(center + Vector3.UP * 15.0, "%d - %s:%.4f" % [_index, _chosen_option.action, _scores[_chosen_option]], 500, Color.GREEN_YELLOW, draw_duration)
	#DebugDraw2D.set_text(name + str(_index), "%d - %s:%.4f" % [_index, chosen_option.action, scores[chosen_option]], 0, Color.GREEN_YELLOW, draw_duration)

func _color_from_index() -> Color:
	match _index - 1:
		0: return Color.RED
		1: return Color.GREEN
		2: return Color.BLUE
		3: return Color.YELLOW
		4: return Color.MAGENTA
		5: return Color.CYAN
		6: return Color.PURPLE
		7: return Color.DARK_GREEN
		8: return Color.GAINSBORO
		9: return Color.ORANGE_RED
		_: return Color.BLACK
