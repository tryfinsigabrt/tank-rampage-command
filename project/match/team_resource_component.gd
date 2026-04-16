class_name TeamResourceComponent extends Node

var resources:TeamResources
var team:int

@export
var default_costs:Array[ConstructionResource]

func get_resource_for(asset: Node3D) -> ConstructionResource:
	for resource in default_costs:
		if asset.scene_file_path == resource.team_asset.resource_path:
			return resource
			
	return null
	
func initialize() -> void:
	SignalBus.on_control_point_captured.connect(_on_control_point_captured)
	SignalBus.on_control_point_neutralized.connect(_on_control_point_neutralized)
	SignalBus.on_scrap_field_mined.connect(_on_scrap_field_mined)
	SignalBus.on_scrap_collected.connect(_on_scrap_collected)
		
func spend_resources(asset:Node3D) -> void:
	# Asset costs handled by manufacturing component unless predeployed
	if asset.has_meta(MatchTeam.IS_PREDEPLOYED_KEY):
		var cost: ConstructionResource = get_resource_for(asset)
		if cost:
			cost.spend_personnel_only(resources)
			cost.assign_to(asset)
		else:
			push_warning("%s: No default cost resource found for %s" % [name, asset.name])
	

func refund_unit_cost(unit:Unit) -> void:
	var cost:ConstructionResource = ConstructionResource.get_assigned_resource(unit)
	if cost:
		cost.refund_personnel(resources)
	else:
		push_warning("%s: unit=%s had no construction cost binding!" % [name, unit.name])	
	
func refund_building_cost(building:Building) -> void:
	var cost:ConstructionResource = ConstructionResource.get_assigned_resource(building)
	if cost:
		cost.refund_cost(resources)
	else:
		push_warning("%s: building=%s has no construction cost binding!" % [name, building.name])

func _on_control_point_captured(new_owning_team:int, control_point:ControlPoint) -> void:
	if new_owning_team != team:
		return
		
	var pers:PersonnelResource = resources.personnel
	var cap_bonus:int = pers.control_point_cap_bonus
	
	print_debug("%s: Team %d captured %s - increasing personnel cap from %d -> %d" % \
		[name, team, control_point.name, pers.cap, pers.cap + cap_bonus])
	
	pers.cap += cap_bonus
	
func _on_control_point_neutralized(prev_owning_team:int, control_point:ControlPoint) -> void:
	if prev_owning_team != team:
		return
	
	var pers:PersonnelResource = resources.personnel
	var cap_bonus:int = pers.control_point_cap_bonus
	
	print_debug("%s: Team %d captured %s - decreasing personnel cap from %d -> %d" % \
	[name, team, control_point.name, pers.cap, pers.cap - cap_bonus])
	
	pers.cap -= cap_bonus

func _on_scrap_field_mined(_field:ScrapField, command_center:CommandCenter, count:int) -> void:
	if command_center.team != team:
		return
	
	var scrap:ScrapResource = resources.scrap
	scrap.count += count

func _on_scrap_collected(scrap:ScrapToken, unit:Unit) -> void:
	if not unit.is_on_team(team):
		return
	
	# Only award scrap if it is part of an enemy team - otherwise we are denying the scrap to the other team
	if unit.is_enemy_team(scrap.originating_team):
		print_debug("%s: Team %d collected %d scrap from team %d" % [name, team, scrap.scrap, scrap.originating_team])
		resources.scrap.count += scrap.scrap
	else:
		print_debug("%s: Team %d denied %d scrap from other teams" % [name, team, scrap.scrap])
	
