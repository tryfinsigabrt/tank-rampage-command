class_name WeaponTargetingComponent extends Node

const ComponentName:StringName = &"WeaponTargetingComponent"

@export
var attack_action:PackedScene

@onready var unit_scanner: UnitScanner = $UnitScanner
@onready var threat_scorer: ThreatScorer = $ThreatScorer
@onready var weapons_container: Node = $WeaponsContainer

@export
var my_asset:Node3D

@export
var targeting_locations:Array[Node3D]

class WeaponState:
	var weapon:Weapon
	var attacking:AttackAction
	var firing_location:Node3D
	
var _weapons:Dictionary[int, WeaponState]

var enabled:bool:
	set(value):
		if not unit_scanner:
			return
			
		if value:
			unit_scanner.my_asset = my_asset
		unit_scanner.enabled = value
	get:
		return enabled
	
# Weapon will be a duplicate 
func add_weapon(id:int, weapon:Weapon) -> bool:
	if id in _weapons:
		push_warning("%s: Cannot add weapon=%s as it is already added" % [name, weapon.name])
		return false
		
	var state := WeaponState.new()
	state.weapon = weapon
	
	_weapons[id] = state
	
	if not weapon.get_parent():
		# TODO: Need to set weapon attributes in this case
		weapons_container.add_child(weapon)
		
	return true
	
func remove_weapon(id:int) -> bool:
	if id not in _weapons:
		push_warning("%s: Cannot remove id=%d as it does not exist" % [name, id])
		return false
	
	var weapon:Weapon = _weapons[id].weapon
	if is_instance_valid(weapon) and weapon.get_parent() == weapons_container:
		weapon.queue_free()
		
	_weapons.erase(id)
	return true
	
func _on_unit_scanner_threats_detected(threats: Array[Node3D]) -> void:
	var scores := threat_scorer.get_threat_assets(threats, my_asset.global_position)
	
	# TODO: Assign weapon targeting priorities based on top scores, avoiding re-assigning if close in priority to existing
	# utilizing logic similar to move_and_attack._threats_detected
		
#region Component Registration
static func get_component(node: Node, required:bool = true) -> WeaponTargetingComponent:
	return Components.get_component(ComponentName, node, required) as WeaponTargetingComponent

static func has_component(node: Node) -> bool:
	return Components.has_component(ComponentName, node)
			
func _enter_tree() -> void:
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion
