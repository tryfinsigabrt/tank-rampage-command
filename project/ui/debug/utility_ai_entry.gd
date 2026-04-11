class_name UtilityAIEntry extends Label

const SEPARATOR:String = "==================="

var team:int

var _lines:PackedStringArray
var _refresh:bool
var _index:int

var _handler:UtilityAIHandler

func _ready() -> void:
	_refresh = true
	_handler = Groups.get_child_with_type(self, UtilityAIHandler)
	if not _handler:
		push_error("%s: UtilityAIHandler node not attached to scene!" % name)
		queue_free()
		return

func supports(utility_node_name:StringName) -> bool:
	return _handler.supports(utility_node_name)
	
func update(options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	# Logic copied from utility_ai.gd as scores not exposed directly
	var scores: Dictionary[UtilityAIOption, float]
	for option in options:
		scores[option] = option.evaluate()
	
	options.sort_custom(func(a: UtilityAIOption, b: UtilityAIOption) -> bool: return scores[a] > scores[b])

	_index += 1

	var override_refresh:Variant = _handler.start(team, _index, scores, chosen_option)
	if override_refresh != null:
		_refresh = override_refresh
		
	if _refresh:
		_lines.clear()
		_lines.push_back("TIME (%.1fs)\n%s" % [GameManager.game_timer.time_seconds, SEPARATOR])
		_refresh = false
		_index = 1
	
	var context_header:String = _handler.option_context_to_string(chosen_option)
	if context_header:
		_lines.push_back(context_header)
	_lines.push_back(SEPARATOR)
	
	for option in options:
		var entry:String = "%s%s: %.4f" % [" X " if option == chosen_option else "  ", _handler.option_action_to_string(option), scores[option]]
		_lines.push_back(entry)
		
	_lines.push_back(SEPARATOR)
	text = "\n".join(_lines)
	
	print_debug("%s: %s" % [name, text])
	
	_handler.finish()
		
func complete() -> void:
	_refresh = true
	_index = 0
