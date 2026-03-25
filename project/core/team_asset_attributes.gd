class_name TeamAssetAttributes extends Resource

@export_range(0.0, 1e9, 0.01,"or_greater")
var strength:float = 1.0

## Priority to attack - lower is higher priority
@export_range(0, 1e9, 1, "or_greater")
var attack_priority:int = 0
