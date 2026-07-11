@tool
class_name DialogueLine
extends PanelContainer

@onready var icon_image: TextureRect = %IconImage
@onready var text_label: Label = %TextLabel

@export_range(0.25, 4.0, 0.05) var text_speed: float = 1.0


func start_dialogue() -> void:
	print("[DialogueLine] Starting dialogue line at 0")
	text_label.visible_characters = 0

func set_icon(icon: Texture2D) -> void:
	icon_image.texture = icon

func set_text(text: String) -> void:
	text_label.text = text

func set_alignment(alignment: int) -> void:
	if alignment == 0:
		layout_direction = Control.LAYOUT_DIRECTION_LTR
	elif alignment == 1:
		layout_direction = Control.LAYOUT_DIRECTION_RTL
	else:
		print("[DialogueLine] Unknown layout direction - setting to 'inherited'")
		layout_direction = Control.LAYOUT_DIRECTION_INHERITED

func _process(delta: float) -> void:
	if text_label.visible_characters < text_label.text.length():
		text_label.visible_characters = text_label.visible_characters + ceili(1 * delta * text_speed)
