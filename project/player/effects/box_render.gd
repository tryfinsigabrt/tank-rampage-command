class_name BoxRender extends Node2D

@export
var outline_color:Color = Color.BLUE

@export
var outline_width:float = 1.0

var _rect:Rect2

func _ready() -> void:
	visible = false
	
func display(selection_rect_screen:Rect2) -> void:
	_rect = selection_rect_screen
	show()
	queue_redraw()
	
func _draw() -> void:
	draw_rect(_rect, outline_color, false, outline_width)
