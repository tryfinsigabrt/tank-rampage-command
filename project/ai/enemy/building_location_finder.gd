class_name BuildingLocationFinder extends Node

@export
var building_cluster_max_distance:float = 100.0

@export
var vision_fow_fraction:float = 0.7

@export
var default_build_radius:float = 25.0

@export
var command_center_safety_margin:float = 0.8

@onready var blackboard: EnemyTeamBlackboard = %Blackboard

#var _scrap_field_bounds:Dictionary[int, BoundingCircle]
var _building_clusters:Array[ClusterCircle]

var _building_cluster_creator:ClusterCircleCreator
var _command_center_bounds:BoundingCircle

func _ready() -> void:
	_building_cluster_creator = ClusterCircleCreator.new(building_cluster_max_distance)
	
	var match_team:MatchTeam = GameManager.find_match_team(self)
	if not match_team:
		push_error("%s: Could not find team match!" % name)
		return
	await match_team.wait_for_ready()
	
	# Compute initial clusters
	_update_building_clusters()

func _update_building_clusters() -> void:
	_building_clusters = _building_cluster_creator.compute_clusters(blackboard.team_info.buildings)
	
	# Within each cluster sort the objects by their type
	for cluster in _building_clusters:
		var buildings:Array = cluster.objects
		buildings.sort_custom(func(a:Building, b:Building) -> bool:
			return _order_by_type(a) < _order_by_type(b)
		)
	
static func _order_by_type(building:Building) -> int:
	if building is CommandCenter:
		return 0
	if building is Factory:
		return 1
	if building is Barracks:
		return 2
	return 3
	
func get_command_center_building_bounds(scrap_field:ScrapField) -> BoundingCircle:
	# Need to build within the scrap field - use inscribed for tighter fit
	var scrap_field_bounds:BoundingCircle = BoundingCircle.from_aabb(scrap_field.get_global_bounds(), false)
	var command_center_bounds:BoundingCircle = _get_command_center_bounds()
	# We just need to overlap the scrap bounds
	if command_center_bounds:
		scrap_field_bounds.radius += command_center_bounds.radius * command_center_safety_margin
	
	return scrap_field_bounds

func get_general_building_bounds(type:ConstructionResource.Type) -> Array[BoundingCircle]:
	# Consider each building in the cluster and build within the vision range
	# TODO: Consider building forward operating bases (FOBs) within a unit cluster's vision
	# Prefer locations that do not already have that type
	var cluster_counts:Dictionary[ClusterCircle, int]
	
	for cluster in _building_clusters:
		var buildings: Array = cluster.objects
		for building:Building in buildings:
			var building_type := ConstructionResource.type_from_building(building)
			if building_type == type:
				var cnt:int = cluster_counts.get(cluster, 0)
				cnt += 1
				cluster_counts[cluster] = cnt
	
	_building_clusters.sort_custom(func(a:ClusterCircle, b:ClusterCircle) -> bool:
		return cluster_counts.get(a, 0) < cluster_counts.get(b, 0)
	)
	
	# Final cluster locations based on vision range of buildings in it
	var build_bounds_array:Array[BoundingCircle]
	
	for cluster in _building_clusters:
		var cluster_bounds:BoundingCircle = cluster.to_bounds()
		var center:Vector2 = cluster_bounds.center
		# Radius will be cluster radius + min of object vision radius
		var min_radius:float = INF
		for building:Building in cluster.objects:
			var vision:AiUnitVision = AiUnitVision.get_component(building, false)
			var radius:float
			if vision:
				radius = vision.radius * vision_fow_fraction
			else:
				radius = default_build_radius
			min_radius = minf(radius, min_radius)
		var build_bounds:BoundingCircle = BoundingCircle.new(center, cluster_bounds.radius + min_radius)
		build_bounds_array.push_back(build_bounds)
		
	return build_bounds_array
func _get_command_center_bounds() -> BoundingCircle:
	# Both sides always start with a command center when building is enabled so just compute lazily from first instance
	if _command_center_bounds:
		return _command_center_bounds
	
	for building in blackboard.team_info.buildings:
		if building is CommandCenter:
			var bounds:Bounds = Bounds.new(building.get_global_bounds(), building.bounds_type)
			_command_center_bounds = BoundingCircle.from_bounds(bounds, true if bounds.type == Bounds.Type.SPHERE_CIRCUMSCRIBED else false)
			break
	return _command_center_bounds

func _on_team_units_new_asset_built(asset: Node3D) -> void:
	if asset is not Building:
		return
	_update_building_clusters()
