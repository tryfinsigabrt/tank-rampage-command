@tool
class_name DirectiveSequenceComposite extends SequenceComposite

func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	
	var directive:AiUnitDirectives = actor
	directive.started()

func tick(actor: Node, blackboard: Blackboard) -> int:
	var result := super.tick(actor,blackboard)
	
	if result != RUNNING:
		var directive:AiUnitDirectives = actor
		if result == SUCCESS:
			directive.completed()
		else:
			directive.canceled()
	return result
