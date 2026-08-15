class_name StructureProxyAssetSpawner extends AssetSpawner

var _inventory_component:InventoryComponent

func _ready() -> void:
	var match_team:MatchTeam = Groups.get_parent_with_type(self, MatchTeam)
	assert(match_team or Groups.is_precompiler_running(self), "%s: Spawner not added to a hierarchy with a MatchTeam!" % name)
	if not match_team:
		return
		
	# Need to wait so we can access the component
	await NodeUtils.ensure_ready(match_team)
	_inventory_component = match_team.inventory_component
	assert(_inventory_component, "%s: MatchTeam=%s does not have an InventoryComponent!" % [name, match_team.name])
	
func spawn(resource:ConstructionResource, asset_name:StringName = "") -> Node3D:
	if not _inventory_component:
		return null
		
	var proxy := StructureProxy.new()
	proxy.resource = resource
	if asset_name:
		proxy.name = asset_name
	
	_inventory_component.add_structure(proxy)
	return proxy
