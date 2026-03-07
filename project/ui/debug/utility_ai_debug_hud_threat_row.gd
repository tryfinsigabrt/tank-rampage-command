class_name UtilityAIDebugHudThreatRow extends VBoxContainer

const SEPARATOR:String = "==================="

var team:int

@onready var _label: Label = $Label

var _header:String
var _lines:PackedStringArray
var _ended:bool

func _ready() -> void:
	_header = "TEAM %d\n%s" % [team, SEPARATOR]
	_lines.push_back(_header)
	_label.text = _header

func update(options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	if _ended:
		# Keep header
		_lines.resize(1)
		_ended = false
	
	# Logic copied from utility_ai.gd as scores not exposed directly
	var scores: Dictionary[UtilityAIOption, float]
	for option in options:
		scores[option] = option.evaluate()
	
	options.sort_custom(func(a, b): return scores[a] > scores[b])

	var context:UnitThreatContext = chosen_option.context
	# Options already sorted
	var context_header:String = "CONTEXT: ec=%d fc=%d distance=%.1f estr=%.1f fstr=%.1f" \
		% [context.threat_size, context.assist_size, context.distance,
		 context.threat_cluster_strength, context.assist_cluster_strength]
	_lines.push_back(context_header)
	_lines.push_back(SEPARATOR)

	for option in options:
		var entry:String = "%s%s: %.4f" % [" X " if option == chosen_option else "  ", option.action, scores[option]]
		_lines.push_back(entry)
		
	_lines.push_back(SEPARATOR)
	_label.text = "\n".join(_lines)	

func complete() -> void:
	_ended = true
