class_name NodeUtils

static func ensure_ready(node:Node) -> void:
	if node.is_node_ready():
		return
	await node.ready

## Await result to wait for object to be destroyed
static func wait_free(node: Node) -> void:
	if not is_instance_valid(node):
		return
	
	var tree := node.get_tree()
	# queue_free is scheduled at the end of the current frame
	# if that call is itself deferred we may need to wait multiple frames
	while is_instance_valid(node):
		await tree.process_frame

static func populate_instances(id_list:PackedInt64Array, instances: Array, filter:Callable = Callable()) -> void:
	var existing_size:int = instances.size()
	instances.resize(existing_size + id_list.size())
	
	var total_count:int = 0
	var added_count:int = 0
	
	for id in id_list:
		var value:Object = instance_from_id(id)
		if value:
			total_count += 1
			if not filter or filter.call(value):
				instances[added_count + existing_size] = value
				added_count += 1
			
	var new_entries:int = instances.size() - existing_size
	# Either some were invalid or some were filtered
	if added_count != new_entries:
		instances.resize(existing_size + added_count)

	# Some of the ids were invalid
	if total_count != new_entries:
		var invalid_count:int = new_entries - total_count
		print_debug("NodeUtils: Invalid instances selected - removing %d instances" % invalid_count)
		
		# remove invalid
		var removed_count:int = 0
		for i in range(id_list.size() - 1, -1, -1):
			var id:int = id_list[i]
			if not is_instance_id_valid(id):
				id_list.remove_at(i)
				removed_count += 1
				if removed_count == invalid_count:
					break
