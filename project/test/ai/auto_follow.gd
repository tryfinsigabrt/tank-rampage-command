extends Node

@export
var leader:Unit

func _ready() -> void:
	var follower:Unit = get_parent() as Unit
	assert(follower)
	assert(leader)
	
	if not follower or not leader:
		queue_free()
	
	await get_tree().process_frame
	
	follower.get_or_add_actions().follow(leader)
