@tool
class_name SkipDialogue
extends PanelContainer

signal skip_dialogue_triggered
signal skip_input_held
signal skip_input_canceled

@export_range(0.0, 10.0, 0.1) var time_to_skip: float = 4.0
@export var hide_until_input_received: bool = false
@export var button_icon: Texture2D:
	set = set_button_icon
@export var input_action: StringName = "ui_cancel"

@onready var radial_progress_bar: TextureProgressBar = %RadialProgressBar
@onready var button_icon_rect: TextureRect = %ButtonIcon


func set_progress(progress: float) -> void:
	# Prevent constant updates/signaling when going slightly above or below
	# the thresholds of the progress bar
	var new_progress := clampf(progress, radial_progress_bar.min_value, radial_progress_bar.max_value)
	if radial_progress_bar.value != new_progress:
		#print("New progress=", new_progress, " | Old progress=", radial_progress_bar.value)
		radial_progress_bar.value = progress
		if radial_progress_bar.value == radial_progress_bar.max_value:
			print("Skip dialogue triggered!")
			skip_dialogue_triggered.emit()

func set_button_icon(icon: Texture2D) -> void:
	if is_instance_valid(icon):
		button_icon = icon
		if is_instance_valid(button_icon_rect):
			button_icon_rect.texture = button_icon


func reset_progress() -> void:
	set_progress(0)

func _process(delta: float) -> void:
	if Input.is_action_pressed(input_action):
		#print("Skip action is being pressed! delta=", delta)
		var new_progress := radial_progress_bar.value + delta
		set_progress(new_progress)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed_by_event(input_action, event):
		show()
		#print("Skip dialogue started!")
		skip_input_held.emit()
	elif Input.is_action_just_released_by_event(input_action, event):
		#print("Skip dialogue canceled!")
		reset_progress()
		skip_input_canceled.emit()

func _ready() -> void:
	# Now we just count up to the number of seconds as our max
	radial_progress_bar.max_value = time_to_skip
	reset_progress()
	set_button_icon(button_icon)
	
	if hide_until_input_received:
		hide()
