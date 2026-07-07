@abstract
class_name AbstractBuildPlacementUtilityContext

var id:int
var construction:ConstructionResource

var available_scrap:int

# Based on the available scrap fields for command centers
var target_location_bounds:Array[BoundingCircle]

var cost:int:
	get:
		return construction.cost

var remaining_scrap:float:
	get:
		return float(available_scrap - cost) / available_scrap if available_scrap > 0 else 0.0

var type:ConstructionResource.Type:
	get:
		return construction.type
