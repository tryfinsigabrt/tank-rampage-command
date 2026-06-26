extends Control

@onready var back_button: Button = %BackButton
@onready var tutorial: LevelPanel = $RootMargin/Content/Scroll/LevelList/Tutorial
@onready var level_01: LevelPanel = $RootMargin/Content/Scroll/LevelList/Level01
@onready var level_02: LevelPanel = $RootMargin/Content/Scroll/LevelList/Level02

func _ready() -> void:
	tutorial.title_text = "Tutorial"
	tutorial.description_text = "Learn the basics of selection, movement, construction, and resource gathering."
	tutorial.play_button_text = "Play Tutorial"
	tutorial.play_button_disabled = false
	if not tutorial.play_clicked.is_connected(_on_tutorial_play_button_pressed):
		tutorial.play_clicked.connect(_on_tutorial_play_button_pressed)

	level_01.title_text = "Operation First Strike"
	level_01.description_text = "Break through the the first enemy outpost and establish control of the area."
	level_01.play_button_text = "Play Level 1"
	level_01.play_button_disabled = false
	if not level_01.play_clicked.is_connected(_on_level_1_play_button_pressed):
		level_01.play_clicked.connect(_on_level_1_play_button_pressed)

	level_02.title_text = "Operation Iron Valley"
	level_02.description_text = "Coming Soon."
	level_02.play_button_text = "Coming Soon"
	level_02.play_button_disabled = true

func _on_back_button_pressed() -> void:
	back_button.disabled = true
	await GameManager.scene_manager.main_menu()

func _on_tutorial_play_button_pressed() -> void:
	tutorial.play_button_disabled = true
	await GameManager.scene_manager.play_tutorial()

func _on_level_1_play_button_pressed() -> void:
	level_01.play_button_disabled = true
	await GameManager.scene_manager.play_level(1)
