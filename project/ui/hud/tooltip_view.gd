class_name TooltipView extends PanelContainer

const WIDTH: float = 320.0

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var content_label: Label = %ContentLabel
@onready var extra_label: Label = %ExtraLabel

func set_tooltip_data(data: Dictionary, extra: String = "") -> void:
	title_label.text = str(data.get("title", ""))
	var subtitle := str(data.get("subtitle", ""))
	subtitle_label.text = subtitle
	subtitle_label.visible = not subtitle.is_empty()
	content_label.text = str(data.get("content", ""))
	extra_label.text = extra
	extra_label.visible = not extra.is_empty()


func get_display_size() -> Vector2:
	var min_size := get_combined_minimum_size()
	return Vector2(WIDTH, min_size.y)
