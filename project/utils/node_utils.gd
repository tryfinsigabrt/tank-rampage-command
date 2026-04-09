class_name NodeUtils

static func ensure_ready(node:Node) -> void:
	if node.is_node_ready():
		return
	await node.ready
