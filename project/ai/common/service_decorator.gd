@tool
class_name ServiceDecorator extends Decorator

@export var services: Array[BehaviorService] = []

func tick(actor: Node, blackboard: Blackboard) -> int:
	# Run all services in order
	for service in services:
		if service:
			service.tick_service(actor, blackboard)
	
	# Run the actual behavior tree branch
	var child = get_child(0)
	if child:
		var result = child.tick(actor, blackboard)
		if result == RUNNING:
			running_child = child
		return result
	return FAILURE
