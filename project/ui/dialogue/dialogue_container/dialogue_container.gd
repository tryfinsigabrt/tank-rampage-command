@tool
class_name DialogueContainer
extends PanelContainer

## Alpha to fade the background image to. 1 = fully opaque, 0 = invisible
@export_range(0.0, 1.0) var background_image_fade := 0.8

@onready var background_image: TextureRect = %BackgroundImage
@onready var dialogue_line_container: VBoxContainer = %DialogueLineContainer

var dialogue_line_packed: PackedScene = preload("uid://7xtpwkcqlouy")


func reset_dialogue() -> void:
	print("[DialogueContainer] Resetting dialogue")
	set_background_image(null)
	var current_dialogue_lines := dialogue_line_container.get_children()
	for dialogue_line in current_dialogue_lines:
		dialogue_line.queue_free()

# Set to 'null' to remove the background image
func set_background_image(new_background: Texture2D) -> void:
	background_image.texture = new_background
	fade_background_image()

func add_new_line(text: String, icon: Texture2D = null, alignment: int = -1) -> void:
	print("[DialogueContainer] Adding new line of dialogue")
	var new_dialogue_line: DialogueLine = dialogue_line_packed.instantiate()
	dialogue_line_container.add_child(new_dialogue_line)
	new_dialogue_line.set_text(text)
	if icon != null:
		new_dialogue_line.set_icon(icon)
	if alignment != -1:
		new_dialogue_line.set_alignment(alignment)
	
	new_dialogue_line.start_dialogue()


func fade_background_image() -> void:
	_set_background_image_alpha(background_image_fade)

func reset_background_image_fade() -> void:
	_set_background_image_alpha(1)

func _set_background_image_alpha(new_alpha: float) -> void:
	var self_modulate_color := Color(1,1,1, new_alpha)
	background_image.self_modulate = self_modulate_color
