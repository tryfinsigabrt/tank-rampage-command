## Decision Context for Utility AI mapping input value for considerations
class_name EnemyActionContext extends Resource

var blackboard: EnemyTeamBlackboard

## Normalized distance of most immediate threat
@export var closest_threat_distance:float

## Threat density of units/m^2 on xz plane
@export var threat_density:float

# health units of total marine threats
@export var marine_threats:float
@export var tank_threats:float
@export var artillery_threats:float

# Total available units in health fractions
@export var marines:float
@export var tanks:float
@export var artilleries:float
