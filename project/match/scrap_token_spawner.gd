class_name ScrapTokenSpawner extends Node

@export
var scrap_token_scene:PackedScene

@export
var _match:Match

func _ready() -> void:
	SignalBus.on_unit_killed.connect(_on_unit_killed.unbind(1))
	

func _on_unit_killed(unit:Unit) -> void:
	var resource:ConstructionResource = _get_resource_for(unit)
	if not resource:
		push_warning("%s: No ConstructionResource found for unit=%s" % [name, unit.name])
		return
	
	var scrap_value:int = resource.scrap_value
	if scrap_value <= 0:
		return
	
	var scrap_token:ScrapToken = scrap_token_scene.instantiate()
	scrap_token.originating_team = unit.team
	scrap_token.scrap = scrap_value
	
	# Add to same container as original unit
	unit.get_parent().add_child(scrap_token)
	scrap_token.global_position = unit.global_position
	

func _get_resource_for(unit:Unit) -> ConstructionResource:
	var match_team: MatchTeam = _match.get_team(unit.team)
	if not match_team:
		push_warning("%s: No MatchTeam found for team=%d for unit=%s" % [name, unit.team, unit.name])
		return null
	return match_team.team_resources.get_resource_for(unit)
