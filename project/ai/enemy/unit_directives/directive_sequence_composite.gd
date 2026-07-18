@tool
class_name DirectiveSequenceComposite extends SequenceComposite

var _running:bool = false

func before_run(actor: Node, blackboard: Blackboard) -> void:
	super.before_run(actor, blackboard)
	
	var directive:AiUnitDirectives = actor
	directive.started()
	
	_running = true

func tick(actor: Node, blackboard: Blackboard) -> int:
	var result := super.tick(actor,blackboard)
	
	if result != RUNNING and _running:
		var directive:AiUnitDirectives = actor
		if result == SUCCESS:
			directive.completed()
		else:
			directive.canceled()
		_running = false
	return result

func interrupt(actor: Node, blackboard: Blackboard) -> void:
	if _running:
		var directive:AiUnitDirectives = actor
		directive.canceled()
		_running = false
		
	super(actor, blackboard)
