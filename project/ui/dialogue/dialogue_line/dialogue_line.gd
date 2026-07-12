@tool
class_name DialogueLine
extends PanelContainer

@onready var icon_image: TextureRect = %IconImage
@onready var text_label: Label = %TextLabel
@onready var speaker_label: Label = %SpeakerLabel

@export_range(0.25, 4.0, 0.05) var text_speed: float = 1.0


func load_from_step(dialogue_step: DialogueStep) -> void:
	if dialogue_step.text != null:
		set_text(dialogue_step.text)
	if is_instance_valid(dialogue_step.icon):
		set_icon(dialogue_step.icon)
	if dialogue_step.speaker_name != null:
		set_speaker(dialogue_step.speaker_name)
	if dialogue_step.alignment in DialogueStep.ALIGNMENT.values():
		set_alignment(dialogue_step.alignment)

func start_dialogue() -> void:
	print("[DialogueLine] Starting dialogue line at 0")
	text_label.visible_characters = 0

func set_icon(icon: Texture2D) -> void:
	icon_image.texture = icon

func set_text(text: String) -> void:
	text_label.text = text

func set_speaker(speaker: String) -> void:
	speaker_label.text = speaker

func set_alignment(alignment: int) -> void:
	if alignment == 0:
		layout_direction = Control.LAYOUT_DIRECTION_LTR
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	elif alignment == 1:
		layout_direction = Control.LAYOUT_DIRECTION_RTL
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		printerr("[DialogueLine] Unknown layout direction - setting to 'inherited'")
		layout_direction = Control.LAYOUT_DIRECTION_INHERITED

func all_text_visible() -> bool:
	return text_label.visible_ratio == 1.0

func show_all_text() -> void:
	text_label.visible_ratio = 1.0


func _process(delta: float) -> void:
	if text_label.visible_ratio < 1.0:
		text_label.visible_characters = text_label.visible_characters + ceili(1 * delta * text_speed)
