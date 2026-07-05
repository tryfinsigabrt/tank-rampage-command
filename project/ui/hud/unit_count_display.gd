class_name UnitCountDisplay
extends HBoxContainer

#region Exports
@export
var unit_container_component: UnitContainerComponent
@export
var unit_icon: Texture2D
@export
var display_on_target_selected: Node3D

@export_subgroup("Fade Details")
## Seconds before the sprite begins visually fading after being displayed.
@export_range(0.0, 100.0)
var time_before_fade: float = 5
## Seconds for the sprite to reach the target fade alpha.
## To instantly hide the sprite, set `fade_time` to 0 and `alpha_fade_to` to 0.
@export_range(0.0, 100.0)
var fade_time: float = 4
## Alpha value to fade the sprite to. Upon fade, the sprite will transition from 1.0 down to this value.
## To instantly hide the sprite, set `fade_time` to 0 and `alpha_fade_to` to 0.
@export_range(0.0, 1.0)
var alpha_fade_to: float = 0.4
## A selectable Node that, when selected, will trigger this sprite to immediately display
#endregion

#region Variables
@onready var unit_icon_display: TextureRect = %UnitIconDisplay
@onready var amount_indicator: Label = %AmountIndicator
@onready var amount_text: Label = %AmountText
@onready var display_timer: Timer = %DisplayTimer

var fade_tween: Tween
var unit_count: int = 0
#endregion


func set_unit_icon(new_texture: Texture2D) -> void:
	unit_icon = new_texture
	unit_icon_display.texture = unit_icon

func set_unit_count(count: int) -> void:
	unit_count = count
	amount_text.text = str(unit_count)
	#print("Unit Count Display is now %s" % [unit_count])
	_sync_display_to_count()

func _update_count() -> void:
	var current_unit_count := _get_container_unit_count()
	set_unit_count(current_unit_count)

func show_display() -> void:
	#print("Unit display is showing!")
	show()
	modulate.a = 255.0
	_handle_display_timer()

func hide_display() -> void:
	#print("Unit display is hiding!")
	hide()
	if not display_timer.is_stopped():
		display_timer.stop()
	if is_instance_valid(fade_tween):
		fade_tween.kill()

func fade_out_display() -> void:
	_handle_fade_out()

func _sync_display_to_count() -> void:
	if _should_display():
		show_display()
	else:
		hide_display()

func _should_display() -> bool:
	return _get_container_unit_count() > 0

func _get_container_unit_count() -> int:
	return unit_container_component.units.size()

func _on_container_unit_added(_unit: Unit) -> void:
	#print("Unit Count Display detected a GAIN of a unit")
	_update_count.call_deferred() # Prevent updating multiple times in one frame

func _on_container_unit_removed(_unit: Unit) -> void:
	#print("Unit Count Display detected a REMOVAL of a unit")
	_update_count.call_deferred() # Prevent updating multiple times in one frame

#region Timer Logic
func _handle_display_timer() -> void:
	# Don't bother 
	if time_before_fade > 0:
		#print("Unit display is starting timer")
		_start_display_timer()

func _start_display_timer() -> void:
	if not display_timer.is_stopped():
		display_timer.stop()
	
	display_timer.one_shot = true
	display_timer.start(time_before_fade)
	if not display_timer.timeout.is_connected(_on_display_timer_timeout):
		display_timer.timeout.connect(_on_display_timer_timeout)

func _on_display_timer_timeout() -> void:
	#print("Unit display timer finished, prepping to fade/hide")
	_handle_fade_out()
#endregion Timer

#region Fade Logic
func _handle_fade_out() -> void:
	# Don't bother fading if there's nothing to fade to
	if alpha_fade_to < 1.0:
		# If we should fade instantly to fully transparent, just hide without a tween
		if fade_time == 0 and alpha_fade_to == 0:
			#print("Unit display instant hide - no fade")
			hide_display()
		else:
			_start_fade_out()

func _start_fade_out() -> void:
	if is_instance_valid(fade_tween):
		fade_tween.kill()
	
	# FIXME: Trying to animate any type of alpha/transparency does not seem to work.
	#  I've tried via the `transparency` on the Sprite3D, the modulate, nothing works quite right
	#  Thinking it might have something to do with the material overlay shader??
	#print("Unit display is fading out")
	fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN)
	var target_modulate := modulate
	target_modulate.a = alpha_fade_to
	#print("unit display target color: %s" % [target_modulate])
	fade_tween.tween_property(self, "modulate", target_modulate, fade_time)
	fade_tween.tween_callback(_on_fade_tween_finished)

func _on_fade_tween_finished() -> void:
	#print("Unit display fade tween finished")
	if is_instance_valid(fade_tween):
		fade_tween.kill()
#endregion Fade

#region Target Selection Logic
# TODO: Abstract target selection to a generic node/component
# List derived from the SignalBus - add more types here if more are added
func _connect_target_selected_callbacks(target: Node3D) -> void:
	if target is Unit:
		SignalBus.on_unit_selected.connect(_on_target_unit_select)
		SignalBus.on_unit_deselected.connect(_on_target_unit_deselected)
	elif target is Building:
		SignalBus.on_building_selected.connect(_on_target_building_select)
		SignalBus.on_building_deselected.connect(_on_target_building_deselected)
	elif target is DefensiveStructure:
		SignalBus.on_structure_selected.connect(_on_target_structure_select)
		SignalBus.on_structure_deselected.connect(_on_target_structure_deselected)

# Unit
func _on_target_unit_select(target_unit: Unit) -> void:
	_handle_target_selected(target_unit)
func _on_target_unit_deselected(target_unit: Unit) -> void:
	_handle_target_deselected(target_unit)
# Building
func _on_target_building_select(target_building: Building) -> void:
	_handle_target_selected(target_building)
func _on_target_building_deselected(target_building: Building) -> void:
	_handle_target_deselected(target_building)
# Structure
func _on_target_structure_select(target_structure: DefensiveStructure) -> void:
	_handle_target_selected(target_structure)
func _on_target_structure_deselected(target_structure: DefensiveStructure) -> void:
	_handle_target_deselected(target_structure)

func _handle_target_selected(target_selected: Node3D) -> void:
	if target_selected == display_on_target_selected:
		#print("Unit display detected that target was selected")
		show_display()

func _handle_target_deselected(target_deselected: Node3D) -> void:
	if target_deselected == display_on_target_selected:
		#print("Unit display detected that target was DEselected")
		hide_display()
#endregion Target Selection

func _ready() -> void:
	assert(is_instance_valid(unit_container_component),
		"%s: UnitCountDisplay has no UnitContainerComponent!" % [name])
	assert(is_instance_valid(unit_icon),
		"%s: UnitCountDisplay has no icon!" % [name])
	
	if is_instance_valid(display_on_target_selected):
		_connect_target_selected_callbacks(display_on_target_selected)
	
	set_unit_icon(unit_icon)
	unit_container_component.on_unit_added.connect(_on_container_unit_added)
	unit_container_component.on_unit_removed.connect(_on_container_unit_removed)
	_sync_display_to_count()
