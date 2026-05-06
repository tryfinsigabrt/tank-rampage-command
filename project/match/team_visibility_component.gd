class_name TeamVisibilityComponent extends Node

signal visibility_changed(object:Node3D, in_is_visible:bool)
signal discovered(object:Node3D)

var team:int

var _vision_counts:Dictionary[int,int] = {}
var _discovered_objects:Dictionary[int, bool] = {}
	
func mark_object_visibility(object:Node3D, in_visible:bool) -> void:
	var id:int = object.get_instance_id()
	var diff:int
	
	if in_visible:
		diff = 1
		if not id in _discovered_objects:
			_discovered_objects[id] = true
			object.tree_exited.connect(func() -> void:
				_discovered_objects.erase(id)
			)
			discovered.emit(object)
	else:
		diff = -1
		
	var updated_count:int = _vision_counts.get(id, 0) + diff
	if updated_count > 0:
		_vision_counts[id] = updated_count
		# Newly visible
		if updated_count == 1:
			if LogUtils.verbose:
				print_debug("%s: object=%s is visible to team %d" % [name, object.name, team])
				
			visibility_changed.emit(object, true)
			
			var team_component:TeamComponent = TeamComponent.get_component(object, false)
			if team_component:
				team_component.set_visible_to(team, true)
	else:
		_vision_counts.erase(id)

		if LogUtils.verbose:
			print_debug("%s: object=%s no longer visible to team %d" % [name, object.name, team])

		visibility_changed.emit(object, false)
		
		var team_component:TeamComponent = TeamComponent.get_component(object, false)
		if team_component:
			team_component.set_visible_to(team, false)
	
func is_discovered(object:Node3D) -> bool:
	return object.get_instance_id() in _discovered_objects

func is_visible(object:Node3D) -> bool:
	return object.get_instance_id() in _vision_counts
