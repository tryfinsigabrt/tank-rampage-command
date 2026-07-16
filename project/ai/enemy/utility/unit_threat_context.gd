class_name UnitThreatContext

var threat_cluster:ClusterCircle
var friendly_cluster:UnitClustering.UnitCluster

var distance:float

var threat_cluster_strength:float
var assist_cluster_strength:float

var threat_size:int:
	get:
		return threat_cluster.count

var assist_size:int:
	get:
		return friendly_cluster.count
