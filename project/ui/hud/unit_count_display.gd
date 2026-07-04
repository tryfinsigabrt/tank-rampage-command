class_name UnitCountDisplay
extends HBoxContainer

#region Exports
@export
var unit_container_component: UnitContainerComponent
@export
var unit_icon: Texture2D
#endregion

#region Variables
@onready var unit_icon_display: TextureRect = %UnitIconDisplay
@onready var amount_indicator: Label = %AmountIndicator
@onready var amount_text: Label = %AmountText

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

func _show_display() -> void:
	show()

func _hide_display() -> void:
	hide()

func _sync_display_to_count() -> void:
	if _should_display():
		_show_display()
	else:
		_hide_display()

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


func _ready() -> void:
	assert(is_instance_valid(unit_container_component),
		"%s: UnitCountDisplay has no UnitContainerComponent!" % [name])
	assert(is_instance_valid(unit_icon),
		"%s: UnitCountDisplay has no icon!" % [name])
	
	set_unit_icon(unit_icon)
	unit_container_component.on_unit_added.connect(_on_container_unit_added)
	unit_container_component.on_unit_removed.connect(_on_container_unit_removed)
	_sync_display_to_count()
