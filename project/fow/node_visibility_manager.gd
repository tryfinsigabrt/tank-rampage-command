class_name NodeVisibilityManager extends Node

@export
var fog_of_war:FogOfWar

@export
var visibility_tick_rate:float = 0.23

## Individual red or green color channel value that is used to check if we flag that node as visible
@export
var visible_channel_threshold:float = 0.3

var _registered_visibility_nodes: Dictionary[int, Node3D] = {}
var _cached_nodes: Array[Node3D]
var _nodes_dirty:bool
var _accum_delta:float

func _enter_tree() -> void:
	SignalBus.on_team_asset_added.connect(_on_team_asset_added)
	SignalBus.on_team_asset_destroyed.connect(_on_team_asset_destroyed.unbind(1))
	SignalBus.on_team_asset_changed_teams.connect(_on_team_asset_changed_teams)
	
func _ready() -> void:
	if not fog_of_war:
		push_error("%s: Fog of War node not set" % name)
		enable = false
		return
			
var enable:bool = true:
	set(value):
		if value == enable:
			return
			
		enable = value
		process_mode = Node.PROCESS_MODE_PAUSABLE if enable else Node.PROCESS_MODE_DISABLED
		
		if not value:
			if SignalBus.on_team_asset_added.is_connected(_on_team_asset_added):
				SignalBus.on_team_asset_added.disconnect(_on_team_asset_added)
			if SignalBus.on_team_asset_destroyed.is_connected(_on_team_asset_destroyed):
				SignalBus.on_team_asset_destroyed.disconnect(_on_team_asset_destroyed)
		
# Use process for smoother tick rate
func _process(delta: float) -> void:
	_accum_delta += delta
	
	if _accum_delta < visibility_tick_rate:
		return
	
	if _nodes_dirty:
		_cached_nodes = _registered_visibility_nodes.values() as Array[Node3D]
		_nodes_dirty = false
		# Skip this frame
		return
		
	_update()
	_accum_delta = 0.0
	
	fog_of_war.fow_visibility_updated.emit()
	
func _update() -> void:
	var points_to_check: PackedVector3Array
		
	for node in _cached_nodes:
		if is_instance_valid(node) and node.is_in_group(Groups.TeamAsset):
			var visible:bool = is_node_visible(node, points_to_check)
			
			var team_component: TeamComponent = node.team_component
			team_component.render = visible
			team_component.set_visible_to(fog_of_war.player_team, visible)

func is_node_visible(node: Node3D, points_to_check: PackedVector3Array = PackedVector3Array(), visible_threshold:float = visible_channel_threshold, channel:int = FogOfWar.FOW_VISIBLE_CHANNEL, require_all:bool = false) -> bool:
	# If overriding fog of war visibility for testing then always make the node visible to player
	if not fog_of_war.visible:
		return true

	if not points_to_check:
		points_to_check.resize(4)
		
	# For units check center point and for other types check bounding box as long as get_global_bounds defined
	var cnt:int = 0
	if node.is_in_group(Groups.Unit) or not node.has_method("get_global_bounds"):
		points_to_check[0] = node.global_position
		cnt = 1
	else:
		var bounds:AABB = node.get_global_bounds()
		
		cnt = 4
		points_to_check[0] = bounds.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_LEFT)
		points_to_check[1] = bounds.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_RIGHT)
		points_to_check[2] = bounds.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_LEFT)
		points_to_check[3] = bounds.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_RIGHT)

	var visible:bool = false
	
	var fow_channel_mask:int = FogOfWar.fow_channel_to_mask(channel)
	for i in cnt:
		var fow_value:Vector2 = fog_of_war.get_fow_value(points_to_check[i], fow_channel_mask)
		#print("FOW(%s-%d): %f" % [node.name, i, fow_color[channel]])
		visible = fow_value[channel] >= visible_threshold
		if visible and not require_all:
			return true
		elif not visible and require_all:
			return false
			
	return visible
	
func _on_team_asset_added(asset:Node3D) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component or team_component.is_on_team(fog_of_war.player_team):
		return
		
	_add_to_visibility_check(asset)


func _on_team_asset_destroyed(asset:Node3D) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component or team_component.is_on_team(fog_of_war.player_team):
		return
		
	_remove_from_visibility_check(asset)
	
func _on_team_asset_changed_teams(asset:Node3D, prev_team:int, new_team:int) -> void:
	var team_component := TeamComponent.get_component(asset)
	if not team_component:
		return
	
	var player_team:int = fog_of_war.player_team
	# We only check visibility for assets not on the player team
	# When the team ownership of an asset changes then we need to re-check
	
	if prev_team == player_team:
		_add_to_visibility_check(asset)
	elif new_team == player_team:
		_remove_from_visibility_check(asset)

func _add_to_visibility_check(asset:Node3D) -> void:
	_registered_visibility_nodes[asset.get_instance_id()] = asset
	_nodes_dirty = true

func _remove_from_visibility_check(asset:Node3D) -> void:
	_registered_visibility_nodes.erase(asset.get_instance_id())
	_nodes_dirty = true
