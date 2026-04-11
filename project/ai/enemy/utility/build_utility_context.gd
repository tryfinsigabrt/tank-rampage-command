class_name BuildUtilityContext
	
var construction:ConstructionResource

var attributes:TeamAssetAttributes:
	get:
		return construction.attributes
		
## Relative strength of this asset
var strength:float:
	get:
		return attributes.strength

## Speed rating (0-1) of this unit
var speed:float:
	get:
		match construction.type:
			ConstructionResource.Type.Marine:
				return 0.5
			ConstructionResource.Type.Tank:
				return 1.0
			ConstructionResource.Type.Artillery:
				return 0.1
			_:
				return 0.0

## What fraction of the total army already has this type?
var army_fraction:float

var available_scrap:int
var available_personnel:int

var cost:int:
	get:
		return construction.cost

var personnel:int:
	get:
		return construction.personnel

var remaining_scrap:float:
	get:
		return float(available_scrap - cost) / available_scrap if available_scrap > 0 else 0.0

var remaining_personnel:int:
	get:
		return available_personnel - personnel

## How many more of this given type does the enemy have over us?
## If multiple enemies take the max
var enemy_delta:int
