@tool
class_name DialogueContainer
extends PanelContainer

## Alpha to fade the background image to. 1 = fully opaque, 0 = invisible
@export_range(0.0, 1.0) var background_image_fade := 0.7

@onready var background_image: TextureRect = %BackgroundImage
@onready var title_label: Label = %TitleLabel
@onready var dialogue_line_container: VBoxContainer = %DialogueLineContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var skip_dialogue: SkipDialogue = %SkipDialogue

var dialogue_line_packed: PackedScene = preload("uid://7xtpwkcqlouy")
var last_line_added: DialogueLine

func reset_dialogue() -> void:
	print("[DialogueContainer] Resetting dialogue")
	set_background_image(null)
	var current_dialogue_lines := dialogue_line_container.get_children()
	for dialogue_line in current_dialogue_lines:
		dialogue_line.queue_free()

func set_title(new_title: String) -> void:
	title_label.text = new_title 

# Set to 'null' to remove the background image
func set_background_image(new_background: Texture2D) -> void:
	if is_instance_valid(new_background):
		background_image.texture = new_background
		fade_background_image()

func add_new_line(dialogue_step: DialogueStep) -> void:
	print("[DialogueContainer] Adding new line of dialogue")
	var new_dialogue_line: DialogueLine = dialogue_line_packed.instantiate()
	dialogue_line_container.add_child(new_dialogue_line)
	
	new_dialogue_line.load_from_step(dialogue_step)
	new_dialogue_line.start_dialogue()
	new_dialogue_line.grab_focus()
	last_line_added = new_dialogue_line

func is_last_line_finished() -> bool:
	return last_line_added.all_text_visible()

func show_all_text_for_last_line() -> void:
	last_line_added.show_all_text()

func fade_background_image() -> void:
	_set_background_image_alpha(background_image_fade)

func reset_background_image_fade() -> void:
	_set_background_image_alpha(1)

func _set_background_image_alpha(new_alpha: float) -> void:
	var self_modulate_color := Color(1,1,1, new_alpha)
	background_image.self_modulate = self_modulate_color


func _process(_delta: float) -> void:
	if is_instance_valid(last_line_added) and not last_line_added.all_text_visible():
		_scroll_to_bottom.call_deferred()

func _scroll_to_bottom() -> void:
	var max_scroll := scroll_container.get_v_scroll_bar().max_value
	scroll_container.scroll_vertical = int(max_scroll)
