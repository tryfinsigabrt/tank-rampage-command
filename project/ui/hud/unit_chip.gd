class_name UnitChip extends PanelContainer

const HEALTH_GREEN := Color(0.23529412, 0.84705883, 0.32941177, 1)
const HEALTH_YELLOW := Color(0.9411765, 0.7607843, 0.23921569, 1)
const HEALTH_RED := Color(0.88235295, 0.26666668, 0.23921569, 1)

@export var unit: Unit
@onready var icon: TextureRect = %UnitIcon
@onready var empty_label: Label = %EmptyLabel
@onready var health_fill: ColorRect = %HealthFill
@onready var health_track: PanelContainer = %HealthTrack

var _health: HealthStat
var _max_health_fill_x: int = 52
var _is_empty: bool = false

func set_empty() -> void:
	_disconnect_health()
	_is_empty = true
	unit = null
	if is_node_ready():
		_apply_unit()

func _ready() -> void:
	call_deferred("_apply_unit")

func _exit_tree() -> void:
	_disconnect_health()

func _apply_unit() -> void:
	if not is_node_ready():
		return

	_disconnect_health()
	if unit == null:
		icon.visible = false
		empty_label.visible = _is_empty
		health_track.visible = false
		_update_health_bar(0.0)
		return

	_is_empty = false
	icon.visible = true
	empty_label.visible = false
	icon.modulate = Color.WHITE
	health_track.visible = true

	var resource := ConstructionResource.get_assigned_resource(unit)
	if resource and resource.icon:
		icon.texture = resource.icon

	_health = unit.health
	if _health:
		_health.health_changed.connect(_on_health_changed)
		_update_health_bar(_health.health_fraction)
	else:
		_update_health_bar(0.0)

func _disconnect_health() -> void:
	if _health and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	_health = null

func _on_health_changed(_previous_health: float, current_health: float) -> void:
	if _health == null or _health.max_health <= 0.0:
		_update_health_bar(0.0)
		return
	_update_health_bar(current_health / _health.max_health)

func _update_health_bar(fraction: float = -1.0) -> void:
	if not is_node_ready() or health_fill == null:
		return

	var health_fraction: float = clampf(fraction, 0.0, 1.0)

	health_fill.size.x = _max_health_fill_x * health_fraction
	health_fill.color = Color(1, 1, 1, 0.12) if _is_empty else _health_color(health_fraction)

func _health_color(fraction: float) -> Color:
	if fraction >= 0.5:
		return HEALTH_GREEN
	if fraction > 0.2:
		return HEALTH_YELLOW
	return HEALTH_RED
