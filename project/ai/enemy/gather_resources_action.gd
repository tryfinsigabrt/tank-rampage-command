@tool
extends ActionLeaf

class ScrapContext:
	var resource: ScrapResource
	var score:float

func tick(_actor: Node, _blackboard: Blackboard) -> int:	
	var blackboard:EnemyTeamBlackboard = _blackboard
	
	var resources: Array[ScrapResource] = _get_resources(blackboard.active_resources)
	if not resources:
		return SUCCESS
	
	# Prioritize and decide whether to move idle units with move and attack to a resource
	# Send multiple units to a resource if it requires an "escort" due to the 	
	return SUCCESS

func _get_resources(resource_ids:PackedInt64Array) -> Array[ScrapResource]:
	var resources:Array[ScrapResource]
	resources.resize(resource_ids.size())
	
	var count:int = 0
	for id in resource_ids:
		var resource:ScrapResource = instance_from_id(id) as ScrapResource
		if resource:
			resources[count] = resource
			count += 1
	resources.resize(count)
	
	return resources
