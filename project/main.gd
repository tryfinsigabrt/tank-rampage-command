extends Node

func _ready() -> void:
	# Fix start up error with "parent node is busy setting up children" in web builds
	await get_tree().process_frame
