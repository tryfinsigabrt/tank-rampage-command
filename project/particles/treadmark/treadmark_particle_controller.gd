extends CPUParticles3D

# only emit particles if we are moving

var prevPos := Vector3()

func _process(_delta: float) -> void:
	var dist := prevPos.distance_to(get_parent().position)
	#print("move dist: "+str(dist))
	emitting = dist > 0
	prevPos = get_parent().position
