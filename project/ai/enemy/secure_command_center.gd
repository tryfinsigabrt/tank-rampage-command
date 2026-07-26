class_name SecureCommandCenter extends Node

const ASSISTANCE_PRIORITY_V_STRENGTH = preload("uid://gx25ih6immna")

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

## Temporary flag during testing
@export
var enable_assistance:bool

@export
var min_discovery_hold_strength:float = 10.0

@export
var ideal_enemy_army_hold_strength:float = 0.1

@export
var discovery_hold_duration:float = 30.0

@export
var secure_hold_additional_duration:float = 30.0

@export
var min_secure_strength:float = 20.0

@export
var ideal_enemy_army_secure_fraction:float = 0.3

@export
var assistance_positioning_bounds_multiplier:float = 2.0

func _on_enemy_building_create_action_on_building_complete(_context: AbstractBuildPlacementUtilityContext, building: Building) -> void:
	if not enable_assistance or building is not CommandCenter:
		return
	
	var construction_building: ConstructionBuilding = Groups.get_child_with_type(building, ConstructionBuilding)
	var hold_duration:float = secure_hold_additional_duration
	if construction_building:
		# Secure additionally for remaining build time
		hold_duration += construction_building.build_time_remaining

	_secure_base(building, hold_duration)

func _watch_scrap_field(scrap_field:EnemyTeamBlackboard.ScrapFieldData) -> void:
	if not scrap_field.open:
		return
	 
	var strength:float = _get_ideal_strength(min_discovery_hold_strength, ideal_enemy_army_hold_strength)
	_issue_assistance(instance_from_id(scrap_field.id), strength, discovery_hold_duration)
	
func _issue_assistance(resource_or_asset:Node3D, strength:float, time:float) -> void:
	if not resource_or_asset:
		return
		
	var boundingSphere := Bounds.create_circumscribed_sphere(resource_or_asset.get_bounds())
	var dir:Vector2 = MathUtils.get_rand_vector2_dir()
	var distance_multiplier:float = randf_range(1.0, assistance_positioning_bounds_multiplier)
	var location_offset:Vector3 = Vector3(dir.x, 0.0, dir.y) * boundingSphere.radius * distance_multiplier
	var location:Vector3 = boundingSphere.center + location_offset
	
	var assistance := EnemyTeamBlackboard.AssistanceRequest.new()
	assistance.requesting_party_id = resource_or_asset.get_instance_id()
	assistance.timestamp = GameManager.game_timer.time_seconds
	assistance.strength = strength
	assistance.location = location
	assistance.min_duration = time
	assistance.priority = roundi(ASSISTANCE_PRIORITY_V_STRENGTH.sample(strength))
	
	if LogUtils.debug:
		print_debug("%s: Assistance request issued for %s with strength = %.1f and priority = %d" % [name, resource_or_asset.name, strength, assistance.priority])
	
	blackboard.assistance_requests.push_back(assistance)
	
func _get_ideal_strength(min_strength:float, enemy_fraction:float) -> float:
	var enemy_teams := blackboard.enemy_teams_info
	var total_strength:float = 0.0
	
	for team:EnemyTeamUnits in enemy_teams:
		var assets := team.assets
		for asset_id in assets:
			var asset_data:UnitData = assets[asset_id]
			if asset_data.valid:
				var unit:Unit = asset_data.asset as Unit
				if unit:
					total_strength += unit.strength()
	return maxf(min_strength, total_strength * enemy_fraction)
				
func _secure_base(building:Building, duration:float) -> void:
	if not enable_assistance:
		return
	
	var strength:float = _get_ideal_strength(min_secure_strength, ideal_enemy_army_secure_fraction)
	_issue_assistance(building, strength, duration)

func _on_team_units_scrap_field_discovered(scrap_field: ScrapField) -> void:
	if not enable_assistance:
		return
		
	# Need to defer to make sure visibility and team ownership is updated
	await get_tree().process_frame
	
	# However unlikely it's possible the scrap field is now no longer valid
	var id:int = scrap_field.get_instance_id() if is_instance_valid(scrap_field) else -1
	_watch_scrap_field(blackboard.get_active_scrap_field_by_id(id))
