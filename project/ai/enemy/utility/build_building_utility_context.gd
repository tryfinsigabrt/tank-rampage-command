class_name BuildBuildingUtilityContext

var construction:ConstructionResource

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

var viable_locations: Array[BoundingSphere]
