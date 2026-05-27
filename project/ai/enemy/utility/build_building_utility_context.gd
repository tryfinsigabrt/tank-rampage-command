class_name BuildBuildingUtilityContext

var id:int
var construction:ConstructionResource

var available_scrap:int

# Based on the available scrap fields for command centers
var target_location_bounds:Array[BoundingCircle]

var curr_unit_count:int

#region Barracks or Factory
# Average capacity usage across all buildings of this type
var avg_queue_depth_fraction:float
var curr_building_count:int

#endregion

#region Command Center
# Field with highest depletion fraction
# 1.0 is fully depleted
var most_depleted_field_fraction:float
# Time before all resources across all fields will be depleted
var time_to_exhaustion:float

var build_site_score:float
#endregion

var cost:int:
	get:
		return construction.cost

var remaining_scrap:float:
	get:
		return float(available_scrap - cost) / available_scrap if available_scrap > 0 else 0.0

var type:ConstructionResource.Type:
	get:
		return construction.type
