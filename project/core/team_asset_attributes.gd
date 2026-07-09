class_name TeamAssetAttributes extends Resource

## Attack strength of the asset
@export_range(0.0, 1e9, 0.01,"or_greater")
var strength:float = 1.0

## Priority to attack - lower is higher priority
@export_range(0, 1e9, 1, "or_greater")
var attack_priority:int = 0

## Relative strength of required defense of this team asset
## Normally only applies to defenseless high value assets like buildings or transports
@export_range(0.0, 1e9, 0.01, "or_greater")
var defense_strength:float = 0.0

## Ideal range to explore - only applies to units
@export
var explore_range:Vector2 = Vector2(100.0, 250.0)
