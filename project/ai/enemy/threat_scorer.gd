class_name ThreatScorer extends Node

@onready var cluster_calculator: UnitClustering = $ClusterCalculator

@export
var threat_score_threshold:float = 0.5

@export
var ideal_distance:float = 300.0

var _ideal_distance_sq:float

func _ready() -> void:
	_ideal_distance_sq = ideal_distance * ideal_distance
	#_max_distance_sq = max_distance * max_distance

func get_threat_assets(assets: Array[Node3D], position:Vector3) -> Array[UnitScore]:
	return _get_threat_assets(assets, position, func(data:Node3D) -> Node3D: return data)
	
func get_visible_threat_units(assets: Array[UnitData], position:Vector3) -> Array[UnitScore]:
	return _get_threat_assets(assets, position, func(data:UnitData) -> Unit: 
		return data.unit if data.valid and data.visible else null
	)
	
func _get_threat_assets(assets: Array, position:Vector3, viable_asset_extractor:Callable) -> Array[UnitScore]:
	var matches:Array[UnitScore]
	if not assets:
		return matches
	
	var max_score:float = 0.0
	
	# TODO: Placeholder Utility AI - use real utility AI system to score and filter candidates
	for unit_data:Variant in assets:
		var asset:Node3D = viable_asset_extractor.call(unit_data) as Node3D
		if asset and asset.is_in_group(Groups.TeamAsset):
			var dist_sq:float = asset.global_position.distance_squared_to(position)
			var score:float = dist_sq
			#if score > _max_distance_sq:
				#continue
			score = _ideal_distance_sq / maxf(score, 0.001)
			max_score = maxf(score, max_score)
			
			var attributes:TeamAssetAttributes = asset.attributes
			
			var entry := UnitScore.new()
			entry.threat = asset
			entry.priority = attributes.attack_priority
			entry.score = score
			entry._dist_sq = dist_sq
			matches.push_back(entry)
	
	# Normalize scores
	for entry in matches:
		entry.score = entry.score / max_score
	matches.sort_custom(func(a:UnitScore, b:UnitScore) -> bool:
		if a.priority < b.priority:
			return true
		return a.score > b.score)
	
	var remove_index_start:int = -1
	for i in range(matches.size() - 1, -1, -1):
		var entry := matches[i]
		if entry.score < threat_score_threshold:
			remove_index_start = i
			break
			
	# Remove from the removal index start by truncating the array
	if remove_index_start >= 0:
		matches.resize(remove_index_start)
		
	return matches	

func calculate_threat_inputs(units: Array[Unit], threats:Array[Unit]) -> Array[UnitThreatContext]:
	var unit_clusters:Array[UnitClustering.UnitCluster] = cluster_calculator.compute_clusters(units)
	var threat_clusters:Array[UnitClustering.UnitCluster] = cluster_calculator.compute_clusters(threats)
	var contexts: Array[UnitThreatContext]
	
	if not unit_clusters or not threat_clusters:
		return contexts
		
	var friendly_cluster_strengths:PackedFloat32Array
	friendly_cluster_strengths.resize(unit_clusters.size())
	
	for threat_cluster in threat_clusters:
		var min_dist_sq:float = INF
		var friendly_cluster_index:int = -1
	
		var threat_center:Vector2 = threat_cluster.center
		for i in unit_clusters.size():
			var unit_cluster:UnitClustering.UnitCluster = unit_clusters[i]
			var dist_sq:float = threat_center.distance_squared_to(unit_cluster.center)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				friendly_cluster_index = i
		
		var friendly_cluster_strength:float = friendly_cluster_strengths[friendly_cluster_index]
		if friendly_cluster_strength == 0.0:
			for unit in unit_clusters[friendly_cluster_index].units:
				friendly_cluster_strength += calculate_strength(unit)
			friendly_cluster_strengths[friendly_cluster_index] = friendly_cluster_strength
			
		var min_dist:float = sqrt(min_dist_sq)
		
		var threat_strength:float = 0.0
		for threat in threat_cluster.units:
			threat_strength += calculate_strength(threat)
			
		var context: UnitThreatContext = UnitThreatContext.new()
		
		context.threat_cluster = threat_cluster
		context.friendly_cluster = unit_clusters[friendly_cluster_index]
		context.distance = min_dist
		context.threat_cluster_strength = threat_strength
		context.assist_cluster_strength = friendly_cluster_strength
		
		contexts.push_back(context)
	
	return contexts

func calculate_strength(unit:Unit) -> float:
	var strength:float = unit.attributes.strength
	var health_stat:HealthStat = unit.health
	if health_stat:
		strength *= unit.health.health_fraction
	return strength
