class_name Credits
extends Control

@export_category("Credits!")
## File containing the credits text to display. (WYSIWYG-ish)
@export_file("*.txt") var credits_file: String
@export_range(0.5, 5.0, 0.1) var scroll_speed: float = 1.0

@export_category("Backgrounds")
@export_range(2.0, 30.0, 0.5) var time_between_background_change: float = 12.0
@export_range(0.5, 10.0, 0.05) var fade_time: float = 3.0
@export var background_image_rotation: Array[Texture2D]

const TANK_RAMPAGE_COMMAND_LOGO = preload("uid://dc5a7y68hy2il")
const SCROLL_SCALAR: float = 50.0
const MAX_BACKGROUND_ALPHA: float = 0.87

@onready var background_texture: TextureRect = %BackgroundTexture
@onready var logo_texture_rect: TextureRect = %LogoTextureRect
@onready var logo_container: MarginContainer = %LogoContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var scroll_contents: VBoxContainer = %ScrollContents
@onready var credits_container: VBoxContainer = %CreditsContainer
@onready var static_credits_label: RichTextLabel = %StaticCreditsLabel
@onready var bottom_filler: Panel = %BottomFiller
@onready var main_menu_button: Button = %MainMenuButton

var current_background_index: int = 0
var auto_scroll_enabled := false


func scroll_credits_by_delta(delta: float) -> void:
	var new_scroll_value := ceili(SCROLL_SCALAR * delta * scroll_speed)
	scroll_container.scroll_vertical += new_scroll_value
	
	var max_scroll_value := scroll_contents.size.y - scroll_container.size.y
	if scroll_container.scroll_vertical == max_scroll_value:
		print("Scrolling done")
		auto_scroll_enabled = false

func _process(delta: float) -> void:
	if auto_scroll_enabled:
		scroll_credits_by_delta(delta)

func inject_credits_to_container() -> void:
	var file := FileAccess.open(credits_file, FileAccess.READ)
	var file_contents := file.get_as_text()
	static_credits_label.text = file_contents
	print("injected credits")


#region Start Logic
func start_credit_sequence() -> void:
	current_background_index = 0
	auto_scroll_enabled = false
	background_texture.self_modulate = Color(1,1,1,0)
	logo_texture_rect.self_modulate = Color(1,1,1,0)
	set_background_by_index(current_background_index)
	fade_in_background(_initiate_credit_scroll)

func _initiate_credit_scroll() -> void:
	_fade_in_logo()

func _fade_in_logo() -> void:
	var bg_tween := create_tween()
	bg_tween.tween_property(logo_texture_rect, "self_modulate", Color(1,1,1,1), fade_time)
	bg_tween.tween_callback(_begin_credit_scroll)

func _begin_credit_scroll() -> void:
	print("initiating credits scroll")
	auto_scroll_enabled = true
	_start_timer_for_next_background_change()
#endregion Start Logic

#region Background Management
func set_background_by_index(index: int) -> void:
	var next_background: Texture2D = background_image_rotation.get(index)
	background_texture.texture = next_background

func fade_in_background(fade_in_callback: Callable = _on_background_fade_in_complete) -> void:
	var bg_tween := create_tween()
	bg_tween.tween_property(background_texture, "self_modulate", Color(1,1,1,MAX_BACKGROUND_ALPHA), fade_time)
	bg_tween.tween_callback(fade_in_callback)

func _on_background_fade_in_complete() -> void:
	print("background done fade IN complete")
	_start_timer_for_next_background_change()

func _start_timer_for_next_background_change() -> void:
	var scene_tree_timer := get_tree().create_timer(time_between_background_change)
	scene_tree_timer.timeout.connect(fade_out_background)

func fade_out_background(fade_out_callback: Callable = _on_background_fade_out_complete) -> void:
	var bg_tween := create_tween()
	bg_tween.tween_property(background_texture, "self_modulate", Color(1,1,1,0), fade_time)
	bg_tween.tween_callback(fade_out_callback)

func _on_background_fade_out_complete() -> void:
	print("background done fade OUT complete")
	_fade_in_next_background()

func _fade_in_next_background() -> void:
	go_to_next_background()
	fade_in_background()

func go_to_next_background() -> void:
	current_background_index = (current_background_index + 1) % background_image_rotation.size()
	set_background_by_index(current_background_index)
#endregion Background Management

func return_to_main_menu() -> void:
	GameManager.scene_manager.main_menu()

func _on_main_menu_button_pressed() -> void:
	return_to_main_menu()

func _set_initial_container_sizes() -> void:
	var current_min_size := logo_container.custom_minimum_size
	var viewport_height := get_viewport().get_visible_rect().size.y
	var target_min_size := Vector2(current_min_size.x, viewport_height)
	logo_container.custom_minimum_size = target_min_size
	bottom_filler.custom_minimum_size = target_min_size

func _ready() -> void:
	# Calling this after one frame in case the window isn't settled
	# (like when loading this scene directly)
	_set_initial_container_sizes.call_deferred()
	
	inject_credits_to_container()
	start_credit_sequence()
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
