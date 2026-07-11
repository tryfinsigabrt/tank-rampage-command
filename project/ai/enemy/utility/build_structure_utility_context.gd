class_name BuildStructureUtilityContext extends AbstractBuildPlacementUtilityContext
# TODO: Should scale with defense needs
# Control Points and buildings all should have defense
# If units are currently fulfilling the defense needs then the value should go down a bit but units are impermanent defense
# Can look at assistance requests or query ai unit directives

var need_score:float
var required_strength:float
var available_infantry_units:int
