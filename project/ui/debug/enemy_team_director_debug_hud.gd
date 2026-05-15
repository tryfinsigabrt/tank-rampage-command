extends VBoxContainer

@onready var label: Label = %Label

var _team_stat_lines:Dictionary[int,String]
var _buffer1:PackedStringArray
var _buffer2:PackedStringArray

var _base_defense_connections:Array[Signal]

func _ready() -> void:
	var game_match:Match = get_tree().get_first_node_in_group(Groups.Match)
	if not game_match:
		return
	if not game_match.started:
		await SignalBus.match_ready
	
	var max_team_id:int = 0
	for team in game_match.teams:
		if not team.is_player_team:
			# team ids start 1
			max_team_id = maxi(team.team, max_team_id)
			var enemy_dir:EnemyTeamDirector = Groups.get_child_with_type(team, EnemyTeamDirector)
			if enemy_dir:
				var sig:Signal = enemy_dir.blackboard.on_defense_units_updated
				sig.connect(_on_base_defense_units_updated.bind(enemy_dir))
				_base_defense_connections.push_back(sig)
				
func _exit_tree() -> void:
	for sig in _base_defense_connections:
		if is_instance_id_valid(sig.get_object_id()) and sig.is_connected(_on_base_defense_units_updated):
			sig.disconnect(_on_base_defense_units_updated)
	_base_defense_connections.clear()
			
func _on_base_defense_units_updated(enemy_team_director:EnemyTeamDirector) -> void:
	if not is_visible_in_tree():
		return
	
	var team_id:int = enemy_team_director.team
	var defenders:Dictionary[int,int] = enemy_team_director.blackboard.base_defend_units
	var building_unit_counts:Dictionary[Building,Dictionary]
	_buffer1.clear()
	
	for defender_id in defenders:
		var defender:Unit = instance_from_id(defender_id) as Unit
		if not defender:
			continue
		var building:Building = instance_from_id(defenders[defender_id]) as Building
		if not building:
			continue
			
		var counts:Dictionary[Unit.UnitClass,int]
		if building in building_unit_counts:
			counts = building_unit_counts[building]
		else:
			building_unit_counts[building] = counts
		
		var unit_class := defender.unit_class
		var count:int = counts.get(unit_class, 0)
		count += 1
		counts[unit_class] = count
	
	for building in building_unit_counts:
		var counts:Dictionary[Unit.UnitClass,int] = building_unit_counts[building]
		_buffer2.clear()
		for unit_class in counts:
			_buffer2.push_back("%s=%d" % [EnumUtils.enum_to_string(Unit.UnitClass, unit_class), counts[unit_class]])
		var line:String = "%s: %s" % [building.name, "  ".join(_buffer2)]
		_buffer1.push_back(line)
		
	var defense_summary:String = "\n\t".join(_buffer1)
	var time:float = GameManager.game_timer.time_seconds
	_team_stat_lines[team_id] = "TEAM %d DEFENSE(%.1fs)\n%s" % [team_id,time, defense_summary]
	
	_render()
	
func _render() -> void:
	var text:String = "\n\n".join(_team_stat_lines.values())
	label.text = text
