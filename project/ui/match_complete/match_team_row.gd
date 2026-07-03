class_name MatchCompleteTeamRow extends Control

var match_team:MatchTeam

@onready var _team: Label = %Team
@onready var _units_killed: Label = %"Units Killed"
@onready var _units_built: Label = %UnitsBuilt
@onready var _units_lost: Label = %UnitsLost
@onready var _buildings_razed: Label = %BuildingsRazed
@onready var _buildings_built: Label = %BuildingsBuilt
@onready var _buildings_lost: Label = %BuildingsLost

func _ready() -> void:
	assert(match_team)
	if not match_team:
		return
	
	_team.text = str(match_team.team)
	
	var stats:MatchTeamStatTracker = match_team.stat_tracker
	
	_units_killed.text = str(stats.units_killed)
	_units_built.text = str(stats.units_built)
	_units_lost.text = str(stats.units_lost)
	
	_buildings_razed.text = str(stats.buildings_destroyed)
	_buildings_built.text = str(stats.buildings_constructed)
	_buildings_lost.text = str(stats.buildings_lost)
