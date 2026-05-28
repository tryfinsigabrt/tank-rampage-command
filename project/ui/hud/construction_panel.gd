extends PanelContainer

@export var construction_resources: Array[ConstructionResource]

@onready var grid: GridContainer = %Grid

var _match_team: MatchTeam

func _ready() -> void:
	_populate_chips()
	_connect_player_resources()

func _connect_player_resources() -> void:
	var player := get_tree().get_first_node_in_group(Groups.Player) as Player
	if not player:
		_update_affordability(0)
		return

	_match_team = player.player_team
	if not _match_team:
		_update_affordability(0)
		return

	var scrap := _match_team.resources.scrap
	_update_affordability(scrap.count)
	scrap.count_changed.connect(func(old, new): _update_affordability(new))

func _populate_chips() -> void:
	var chips := _get_building_chips()
	for i in chips.size():
		var chip := chips[i]
		var resource := construction_resources[i] if i < construction_resources.size() else null
		chip.resource = resource
		chip.visible = resource != null

	if _match_team:
		_update_affordability(_match_team.resources.scrap.count)


func _update_affordability(scrap_count: int) -> void:
	for chip in _get_building_chips():
		var can_afford := chip.resource != null and scrap_count >= chip.resource.cost
		chip.set_can_afford(can_afford)


func _get_building_chips() -> Array[BuildingChip]:
	var chips: Array[BuildingChip] = []
	for child in grid.get_children():
		var chip := child as BuildingChip
		if chip:
			chips.push_back(chip)
	return chips
