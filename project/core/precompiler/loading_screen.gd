extends Node3D

@onready var precompilation: Precompilation3D = %Precompilation3D
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	precompilation.progress_changed.connect(_progress_changed.unbind(1))

	# Wait until the engine finishes drawing the very first frame
	await RenderingServer.frame_post_draw
	
	await precompilation.run()
	
	await GameManager.scene_manager.main_menu()


func _progress_changed(fraction:float) -> void:
	progress_bar.indeterminate = false
	progress_bar.value = fraction
