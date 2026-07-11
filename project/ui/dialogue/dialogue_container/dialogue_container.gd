@tool
class_name DialogueContainer
extends PanelContainer

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
