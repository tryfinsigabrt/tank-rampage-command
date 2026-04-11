class_name UtilityAIDebugHudRow extends VBoxContainer

const SEPARATOR:String = "==================="

var team:int

@onready var _label: Label = $Label
@onready var utility_container: HBoxContainer = $UtilityContainer

var _utilities: Array[UtilityAIEntry]

func _ready() -> void:
	_label.text = "TEAM %d\n%s" % [team, SEPARATOR]
	
	for child in utility_container.get_children():
		var utility:UtilityAIEntry = child as UtilityAIEntry
		if not utility:
			continue
		
		utility.team = team
		_utilities.push_back(utility)
	
func update(node_name:StringName, options:Array[UtilityAIOption], chosen_option: UtilityAIOption) -> void:
	for utility in _utilities:
		if utility.supports(node_name):
			utility.update(options, chosen_option)
			break
		
		
func complete(node_name:StringName) -> void:
	for utility in _utilities:
		if utility.supports(node_name):
			utility.complete()
			break
