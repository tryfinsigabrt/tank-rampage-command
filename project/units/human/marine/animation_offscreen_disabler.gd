extends VisibleOnScreenNotifier3D

@export var animation_player: AnimationPlayer

func _ready() -> void:
	if not animation_player:
		queue_free()
		
	else:
		
		screen_entered.connect(_on_screen_entered)
		screen_exited.connect(_on_screen_exited)

func _on_screen_entered() -> void: animation_player.active = true
func _on_screen_exited() -> void: animation_player.active = false
