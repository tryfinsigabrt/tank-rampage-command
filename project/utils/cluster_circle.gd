## Copied from UnitClustering and made more generic
class_name ClusterCircle

var objects:Array
var size:float = 1.0
var center:Vector2

func to_bounds() -> BoundingCircle:
	return BoundingCircle.new(center, size)

func _init(object:Variant, pos:Vector2) -> void:
	objects.push_back(object)
	center = pos
	
# Incremental centroid
func add(object:Variant, pos:Vector2) -> void:
	var cnt:int = count
	center = (center * cnt + pos) / (cnt + 1)
	# Update distance after center for tighter fit
	size = maxf(size, pos.distance_squared_to(center))
	objects.push_back(object)
			
var count:int:
	get:
		return objects.size()
