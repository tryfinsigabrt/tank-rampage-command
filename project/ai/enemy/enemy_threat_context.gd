class_name EnemyThreatContext

var bounds: BoundingCircle
var strength:float
var count:int

static func from_unit_threat_context(unit_threat_context:UnitThreatContext) -> EnemyThreatContext:	
	var enemy_cluster := unit_threat_context.threat_cluster
	var cluster_bounds:BoundingCircle = BoundingCircle.new(enemy_cluster.center, enemy_cluster.size)
		
	var ctx := EnemyThreatContext.new()
	ctx.bounds = cluster_bounds
	ctx.strength = unit_threat_context.threat_cluster_strength
	ctx.count = unit_threat_context.threat_size
	
	return ctx
