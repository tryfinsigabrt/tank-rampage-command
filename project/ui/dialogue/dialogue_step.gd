@tool
class_name DialogueStep
extends Object

enum ALIGNMENT {LEFT, RIGHT}

var text: String
var speaker_name: String
var icon: Texture2D
var alignment: ALIGNMENT = ALIGNMENT.LEFT
var background_image: Texture2D

func load_from_dictionary(dictionary_step: Dictionary) -> void:
	if dictionary_step.has("text"):
		text = dictionary_step.get("text")
	if dictionary_step.has("speaker"):
		speaker_name = dictionary_step.get("speaker")
	
	if dictionary_step.has("icon"):
		var icon_image := load(dictionary_step.get("icon"))
		if icon_image is Texture2D:
			icon = icon_image
		else:
			printerr("[DialogueSource] Failed to load icon image at path: %s" % [dictionary_step.get("icon")])
	
	if dictionary_step.has("alignment"):
		if int(dictionary_step.get("alignment")) in ALIGNMENT.values():
			alignment = dictionary_step.get("alignment")
		else:
			printerr("[DialogueSource] Unknown alignment value! Using default alignment instead. Alignment=%s" % [dictionary_step.get("alignment")])
	
	if dictionary_step.has("background"):
		var loaded_bg_image := load(dictionary_step.get("background"))
		if loaded_bg_image is Texture2D:
			background_image = loaded_bg_image
		else:
			printerr("[DialogueSource] Failed to load background image at path: %s" % [dictionary_step.get("background")])

func load_from_json(json_step: JSON) -> void:
	var json_data: Dictionary = json_step.data
	load_from_dictionary(json_data)
