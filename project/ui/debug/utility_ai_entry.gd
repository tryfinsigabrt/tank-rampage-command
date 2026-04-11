class_name UtilityAIEntry extends Label

const SEPARATOR:String = "==================="

var team:int

var _lines:PackedStringArray
var _ended:bool
var _index:int

var _handler:UtilityAIHandler

func _ready() -> void:
	_handler = Groups.get_child_with_type(self, UtilityAIHandler)
	if not _handler:
		push_error("%s: UtilityAIHandler node not attached to scene!" % name)
		queue_free()
		return

func supports(utility_node_name:StringName) -> bool:
	return _handler.supports(utility_node_name)
	
func update(options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	if _ended:
		_lines.clear()
		_lines.push_back("UNIT THREATS (%.1fs)\n%s" % [GameManager.game_timer.time_seconds, SEPARATOR])
		_ended = false
	
	_index += 1

	# Logic copied from utility_ai.gd as scores not exposed directly
	var scores: Dictionary[UtilityAIOption, float]
	for option in options:
		scores[option] = option.evaluate()
	
	options.sort_custom(func(a: UtilityAIOption, b: UtilityAIOption) -> bool: return scores[a] > scores[b])

	_handler.start(team, _index, scores, chosen_option)
	
	var context_header:String = _handler.option_context_to_string(chosen_option)
	if context_header:
		_lines.push_back(context_header)
	_lines.push_back(SEPARATOR)
	
	for option in options:
		var entry:String = "%s%s: %.4f" % [" X " if option == chosen_option else "  ", _handler.option_action_to_string(option), scores[option]]
		_lines.push_back(entry)
		
	_lines.push_back(SEPARATOR)
	text = "\n".join(_lines)
	
	_handler.finish()
		
func complete() -> void:
	_ended = true
	_index = 0
