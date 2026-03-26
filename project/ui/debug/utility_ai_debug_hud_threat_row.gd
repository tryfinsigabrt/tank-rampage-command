class_name UtilityAIDebugHudThreatRow extends VBoxContainer

const SEPARATOR:String = "==================="

var team:int

@onready var _label: Label = $Label

var _lines:PackedStringArray
var _ended:bool
var _index:int

@export
var draw_duration:float = 3.0

func update(options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	if _ended:
		_lines.clear()
		_lines.push_back("TEAM %d (%.1fs)\n%s" % [team, GameManager.game_timer.time_seconds, SEPARATOR])
		_ended = false
	
	_index += 1
	
	var d_config := DebugDraw3D.new_scoped_config()
	#d_config.set_text_fixed_size(true)
	d_config.set_text_outline_size(4)
	#d_config.set_no_depth_test(true)
	d_config.set_thickness(0.5)

	# Logic copied from utility_ai.gd as scores not exposed directly
	var scores: Dictionary[UtilityAIOption, float]
	for option in options:
		scores[option] = option.evaluate()
	
	options.sort_custom(func(a: UtilityAIOption, b: UtilityAIOption) -> bool: return scores[a] > scores[b])

	var context:UnitThreatContext = chosen_option.context
	# Options already sorted
	var context_header:String = "CONTEXT(%d): size=%.1f ec=%d fc=%d distance=%.1f estr=%.1f fstr=%.1f" \
		% [_index, context.threat_cluster.size, context.threat_size, context.assist_size, context.distance,
		 context.threat_cluster_strength, context.assist_cluster_strength]
	_lines.push_back(context_header)
	_lines.push_back(SEPARATOR)
	
	for option in options:
		var entry:String = "%s%s: %.4f" % [" X " if option == chosen_option else "  ", option.action, scores[option]]
		_lines.push_back(entry)
		
	_lines.push_back(SEPARATOR)
	_label.text = "\n".join(_lines)
	
	# Draw also in world
	var cluster_center:Vector2 = context.threat_cluster.center
	var y:float = context.threat_cluster.units.front().global_position.y
	var center:Vector3 = Vector3(cluster_center.x, y, cluster_center.y)
	DebugDraw3D.draw_sphere(center, context.threat_cluster.size, _color_from_index(), draw_duration)
	
	# Doesn't work with FOW as the FOW quad post-process shader gets drawn over the label
	DebugDraw3D.draw_text(center + Vector3.UP * 15.0, "%d - %s:%.4f" % [_index, chosen_option.action, scores[chosen_option]], 500, Color.GREEN_YELLOW, draw_duration)
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
		
func complete() -> void:
	_ended = true
	_index = 0
