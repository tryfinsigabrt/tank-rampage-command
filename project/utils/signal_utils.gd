class_name SignalUtils


## Connects the given callable and binds an additional special signal that should be emitted when the original callable should be disconnected
static func connect_with_predicated_disconnect(sig:Signal, callable:Callable, id:String = "") -> void:
	var owner:Object = callable.get_object()
	var owner_valid:bool = is_instance_valid(owner)
	
	assert(owner_valid)
	if not owner_valid:
		return
	
	var disconnect_signal_name:StringName = id if id else "%s_disconnect_%d" % [sig.get_name(), callable.hash()]
	
	# If use the same id then the callables share the same disconnect signal
	if not owner.has_user_signal(disconnect_signal_name):
		owner.add_user_signal(disconnect_signal_name)
		
	var disconnect_emitter := Signal(owner, disconnect_signal_name)
	var predicated_callable:Callable = callable.bind(disconnect_emitter)

	disconnect_emitter.connect(func() -> void:
		if sig.is_connected(predicated_callable):
			sig.disconnect(predicated_callable)
	, CONNECT_ONE_SHOT)
		
	sig.connect(predicated_callable)
