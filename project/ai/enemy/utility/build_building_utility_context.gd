class_name BuildBuildingUtilityContext extends AbstractBuildPlacementUtilityContext

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
