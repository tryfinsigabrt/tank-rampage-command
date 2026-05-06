class_name Factory extends Building

func _die(_damage_params: DamageParameters) -> void:
	print_debug("%s: Die" % name)
	queue_free()
	
func _on_health_changed(previous_health: float, current_health: float) -> void:
	if LogUtils.verbose:
		print_debug("%s: health_changed: %f -> %f" % [name, previous_health, current_health])

func _took_damage(_damage_params: DamageParameters) -> void:
	pass
	
