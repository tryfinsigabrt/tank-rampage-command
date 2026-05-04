class_name UIUtils

static var ACTION_KEYS: Array[Key] = [Key.KEY_ENTER, Key.KEY_KP_ENTER]

static func disable_all_buttons(buttons_container: Container, reenable_timeout:float = -1.0) -> void:
	var disabled_buttons:Array[BaseButton] = toggle_all_buttons(buttons_container, true)
	
	if reenable_timeout <= 0:
		return
		
	# If the buttons are still valid after the timeout that means something went wrong, and we didn't transition so
	# re-enable the buttons
	await buttons_container.get_tree().create_timer(reenable_timeout).timeout
	
	for button in disabled_buttons:
		if is_instance_valid(button) and button.disabled:
			push_warning("UIUtils: Re-enabling button %s after timeout of %fs" % [button.name, reenable_timeout])
			button.disabled = false
			
static func enable_all_buttons(buttons_container: Container) -> void:
	toggle_all_buttons(buttons_container, false)
	
static func toggle_all_buttons(buttons_container: Container, desired_disabled_state: bool) -> Array[BaseButton]:
	var toggled_buttons:Array[BaseButton] = []
	
	for control in buttons_container.get_children():
		var button:BaseButton = control as BaseButton
		if button and button.disabled != desired_disabled_state:
			button.disabled = desired_disabled_state
			toggled_buttons.push_back(button)
			
	return toggled_buttons
			
static func desaturate(source:Color, amount:float) -> Color:
	# Desaturate the color
	if source == Color.WHITE:
		var result: Color = source * amount
		result.a = source.a
		return result
	var lum:float = source.get_luminance()
	return source.lerp(Color(lum, lum, lum, 1.0), amount)

static func is_control_action_event(event: InputEvent) -> bool:
	var mouse_event:InputEventMouseButton = event as InputEventMouseButton
	var key_event:InputEventKey = event as InputEventKey
	return (mouse_event and mouse_event.button_index == MouseButton.MOUSE_BUTTON_LEFT) \
		or (key_event and key_event.keycode in ACTION_KEYS)
