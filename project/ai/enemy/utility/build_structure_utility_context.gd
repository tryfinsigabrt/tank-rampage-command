class_name BuildStructureUtilityContext extends AbstractBuildPlacementUtilityContext

var need_score:float
var required_strength:float

# Will be used by bunker type to make sure there are units that can fill the bunker
var available_infantry_units:int	

# Not currently required but adding in case we have structures that require personnel
var available_personnel:int

# Count of this type in inventory or in progress of building
var unused_count:int
