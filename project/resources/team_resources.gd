class_name TeamResources extends Resource

@export
var scrap: ScrapResource

@export
var personnel: PersonnelResource

func initialize() -> TeamResources:
	duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	
	if not scrap:
		scrap = ScrapResource.new()
	if not personnel:
		personnel = PersonnelResource.new()
		
	return self
