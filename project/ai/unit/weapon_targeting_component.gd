class_name WeaponTargetingComponent extends Node

const ComponentName:StringName = &"WeaponTargetingComponent"

signal on_weapon_setup(weapon:Weapon)

@export
var attack_action:PackedScene

@onready var unit_scanner: UnitScanner = $UnitScanner
@onready var threat_scorer: ThreatScorer = $ThreatScorer
@onready var weapons_container: Node = $Weapons
@onready var actions_container: Node = $Actions

@export
var my_asset:Node3D

@export
var targeting_locations:Array[Node3D]

## If set to true then all weapons focus on a single target at a time rather than distribute
@export
var single_target:bool

#region class WeaponState
class WeaponState:
	var weapon:Weapon
	var original_owner:Node
	var original_owner_child_idx:int = -1
	var owned:bool
	var attacking:AttackAction
	var firing_location:Node3D
	
	# CANNOT use NOTIFICATION_PREDELETE because self is no longer valid
	# See https://github.com/godotengine/godot/issues/31166
	#func _notification(what: int) -> void:
		#if what == NOTIFICATION_PREDELETE:
			#destructor()
			
	func destructor() -> void:
		stop_attacking()
		if owned and weapon:
			weapon.queue_free()
			weapon = null
		elif is_instance_valid(weapon) and weapon.get_parent() != original_owner:
			if is_instance_valid(original_owner):
				restore_parent()
			else:
				# Free weapon as original owner is dead
				weapon.queue_free()
				
	func stop_attacking() -> void:
		if is_instance_valid(attacking):
			attacking.queue_free()
		attacking = null
		if is_instance_valid(weapon) and owned:
			weapon.hide()
				
	func restore_parent() -> void:
		if not is_instance_valid(original_owner):
			return
		if change_parent(original_owner):
			if original_owner_child_idx >= 0 and original_owner_child_idx < original_owner.get_child_count():
				original_owner.move_child(weapon, original_owner_child_idx)
					
	func change_parent(new_parent:Node) -> bool:
		assert(new_parent)
		if not is_instance_valid(weapon):
			return false
			
		var current_parent:Node = weapon.get_parent()
		if current_parent != new_parent:
			if current_parent:
				current_parent.remove_child(weapon)
			new_parent.add_child(weapon)
			return true
		return false

#endregion
		
var _weapons:Dictionary[int, WeaponState]

var enabled:bool:
	set(value):
		if not unit_scanner:
			return
		if value == enabled:
			return
				
		if value:
			unit_scanner.my_asset = my_asset
		unit_scanner.enabled = value
	get:
		return enabled
	
# Weapon will be a duplicate 
func add_weapon(id:int, weapon:Weapon, should_duplicate:bool = false) -> bool:
	if id in _weapons:
		push_warning("%s: Cannot add weapon=%s as it is already added" % [name, weapon.name])
		return false
		
	var state := WeaponState.new()
	state.owned = should_duplicate
	
	if should_duplicate:
		weapon = _duplicate_weapon(weapon)
		
	state.weapon = weapon
	
	_weapons[id] = state
	
	if should_duplicate:
		_set_up_weapon(weapon)
		state.original_owner = weapons_container
		weapons_container.add_child(weapon)
		# Use this to modify the weapon like give it a range bonus in case of the bunker
		on_weapon_setup.emit(weapon)
	else:
		state.original_owner = weapon.get_parent()
		state.original_owner_child_idx = weapon.get_index()
	
	enabled = true	
	return true
	
func _duplicate_weapon(weapon:Weapon) -> Weapon:
	weapon = weapon.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
	
	# Disconnect any firing state changed signals on the duplicate
	var firing_state_changed:Signal = weapon.firing_state_changed
	for conn:Dictionary in firing_state_changed.get_connections():
		var cb:Callable = conn.get("callable")
		if cb:
			firing_state_changed.disconnect(cb)
		
	return weapon

func _set_up_weapon(weapon:Weapon) -> void:
	weapon.hide()
	
	var controller := DefaultWeaponController.new()
	controller.weapon = weapon
	controller.asset = my_asset
	
	weapon.weapon_controller = controller
	weapon.shoot_vfx_origin_path = NodePath()
	weapon.allow_source_damage = false
	
	# Hack to get the shoot vfx facing the right way
	weapon.shoot_vfx_use_model_front = false
	
func remove_all_weapons() -> void:
	_destroy_all_weapons()
	enabled = false
	
func _destroy_all_weapons() -> void:
	for id in _weapons:
		var weapon_state:WeaponState = _weapons[id]
		weapon_state.destructor()
	_weapons.clear()
	
func remove_weapon(id:int) -> bool:
	var weapon_state:WeaponState = _weapons.get(id)
	if not weapon_state:
		push_warning("%s: Cannot remove id=%d as it does not exist" % [name, id])
		return false
		
	# WeaponState will destructor will free the weapon if it was owned	
	# but we have a reference to it on the scene_tree exited on AttackScene to null out the 
	# reference so need to explicitly stop any attack here
	_weapons.erase(id)
	
	weapon_state.destructor()

	if _weapons.is_empty():
		enabled = false
		
	return true
	
func _on_unit_scanner_threats_detected(threats: Array[Node3D]) -> void:
	var scores := threat_scorer.get_threat_assets(threats, my_asset.global_position)
	
	print_debug("%s: Discovered %d threats" % [name, scores.size()])
	var num_assignments:int = mini(scores.size(), _weapons.size() if not single_target else mini(_weapons.size(), 1))
	if num_assignments == 0:
		_stop_all()
		return
	
	var weapon_states:Array[WeaponState] = _weapons.values()
	
	var weapons_per_assignment:int = floori(float(weapon_states.size()) / num_assignments)
	var extra:int = weapon_states.size() % weapons_per_assignment
	
	var weapon_count:int = 0
	for i in num_assignments:
		var target_data:UnitScore = scores[i]
		var target:Node3D = target_data.threat
		
		var assigned_count:int = weapons_per_assignment
		if extra > 0:
			assigned_count += 1
			extra -= 1
		for j in assigned_count:
			var best_location := _get_best_location(target)
			var weapon_state := weapon_states[weapon_count]
			
			_start_attacking(weapon_state, target, best_location)
			weapon_count += 1

func _get_best_location(target:Node3D) -> Node3D:
	if not targeting_locations:
		return null
		
	var best_location:Node3D = null
	var best_alignment:float = -INF
	
	var target_position:Vector3 = target.global_position
	for candidate_node in targeting_locations:
		var candidate_pos:Vector3 = candidate_node.global_position
		var to_target := candidate_pos.direction_to(target_position)
		
		var facing_dir:Vector3 = -candidate_node.global_basis.z
		var alignment:float = facing_dir.dot(to_target)
		
		if alignment > best_alignment:
			best_alignment = alignment
			best_location = candidate_node
			
	return best_location
		
func _stop_all() -> void:
	for id in _weapons:
		var weapon_state:WeaponState = _weapons[id]
		if weapon_state.attacking:
			_stop_attacking(weapon_state)
			
func _stop_attacking(weapon_state:WeaponState) -> void:
	var attack_scene:AttackAction = weapon_state.attacking
	if is_instance_valid(attack_scene):
		attack_scene.queue_free()
	weapon_state.attacking = null
	weapon_state.restore_parent()

func _start_attacking(weapon_state:WeaponState, attack_target:Node3D, attack_origin:Node3D) -> void:
	# If we are already attacking target and attack origin is the same then don't change anything
	var weapon:Weapon = weapon_state.weapon
	if is_instance_valid(weapon_state.attacking) and \
		attack_origin == weapon.get_parent() and \
		weapon_state.attacking.targeted_node == attack_target:
		return
		
	# Stop any existing attack
	weapon_state.stop_attacking()
		
	if attack_origin:
		weapon_state.change_parent(attack_origin)
	
	# Create a new attack action
	var action:AttackAction = attack_action.instantiate()
	action.weapon = weapon
	action.targeted_node = attack_target
	action.move_into_range = AttackAction.MoveBehavior.NEVER
	
	# Null out attacking when action frees itself
	action.tree_exited.connect(func() -> void:
		weapon_state.stop_attacking()
		weapon_state.restore_parent()
	)
	weapon_state.attacking = action
	weapon.show()
	actions_container.add_child(action)
	
#region Component Registration
static func get_component(node: Node, required:bool = true) -> WeaponTargetingComponent:
	return Components.get_component(ComponentName, node, required) as WeaponTargetingComponent

static func has_component(node: Node) -> bool:
	return Components.has_component(ComponentName, node)
			
func _enter_tree() -> void:
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
	
	_destroy_all_weapons()
#endregion
