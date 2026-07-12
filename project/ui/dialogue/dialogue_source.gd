@tool
class_name DialogueSource
extends Resource

@export var file: JSON:
	set = set_file

var title: String
var lines: Array[DialogueStep]


func set_file(new_file: JSON) -> void:
	print("[DialogueSource] New file set - loading now")
	file = new_file
	parse_from_file(file)

func parse_from_file(new_file: JSON) -> void:
	# Reset our current contents before loading new data
	title = ""
	lines.clear()
	
	var file_data: Dictionary = new_file.data
	if file_data.has("title"):
		title = file_data.get("title")
	
	if file_data.has("lines"):
		var lines_content: Array[Dictionary] = Array(file_data.get("lines"), TYPE_DICTIONARY, "", null)
		
		parse_lines_from_file(lines_content)


func parse_lines_from_file(lines_content: Array[Dictionary]) -> void:
	print("[DialogueSource] Parsing lines from file contents")
	for line in lines_content:
		var dialogue_step := DialogueStep.new()
		dialogue_step.load_from_dictionary(line)
		lines.append(dialogue_step)


func get_line_at_index(index: int) -> DialogueStep:
	if index < 0:
		printerr("[DialogueSource] Index for line is too small! Getting first line instead.")
		index = 0
	elif index >= lines.size():
		printerr("[DialogueSource] Index for line is too large! Getting last line instead.")
		index = lines.size() - 1
	
	return lines.get(index)


func _get_file_data() -> Variant:
	return file.data
