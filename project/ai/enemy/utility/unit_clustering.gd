class_name UnitClustering extends Node

@export
var max_cluster_size:float = 500.0

class UnitCluster:
	var units:Array[Unit]
	var size:float = 1.0
	var center:Vector2
	
	func _init(unit:Unit, pos:Vector2) -> void:
		units.push_back(unit)
		center = pos
		
	# Incremental centroid
	func add(unit:Unit, pos:Vector2) -> void:
		var cnt:int = count
		center = (center * cnt + pos) / cnt
		# Update distance after center for tighter fit
		size = maxf(size, pos.distance_squared_to(center))
		units.push_back(unit)
				
	var count:int:
		get:
			return units.size()

func compute_clusters(units:Array[Unit]) -> Array[UnitCluster]:
	var clusters:Array[UnitCluster]
	
	# Might be better to sort for more deterministic cluster behavior
	# or support reclustering but this is a good enough approx
	var positions:PackedVector2Array
	positions.resize(units.size())
	
	var cluster_size_sq:float = max_cluster_size * max_cluster_size
	
	for i in units.size():
		var pos:Vector3 = units[i].global_position
		positions[i] = Vector2(pos.x, pos.z)
	
	# Can only be in one cluster
	var used_positions:PackedInt32Array
	used_positions.resize(units.size())
	var used_count:int = 0
	
	var num_units:int = positions.size()
	var done:bool
	
	for i in num_units:
		if i in used_positions:
			continue
			
		var cluster:UnitCluster = UnitCluster.new(units[i], positions[i])
		clusters.push_back(cluster)
		
		used_positions[used_count] = i
		used_count += 1
		if used_count == num_units:
			break
			
		for j in num_units:
			if i == j or j in used_positions:
				continue
			var candidate:Vector2 = positions[j]
			var dist_sq:float = cluster.center.distance_squared_to(candidate)
			if dist_sq <= cluster_size_sq:
				cluster.add(units[j], candidate)
				used_count += 1
				if used_count == num_units:
					done = true
					break
		if done:
			break
						
	for cluster in clusters:
		cluster.size = sqrt(cluster.size)
			
	return clusters
