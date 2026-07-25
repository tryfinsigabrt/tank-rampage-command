class_name ContainerUtility

## Total number of containers of this type
var count:int

## Default capacity per instance
var def_capacity_per_count:int

## Total capacity of this type
var total_capacity:int

## Number of units that could be put in a container
var candidate_unit_count:int

## Current used total capacity for this type
var used_capacity:int

## Number of containers in the excess capacity that are totally empty
var empty_count:int

#region Derived Properties
var excess_capacity:int:
	get:
		return total_capacity - used_capacity

var empty_fraction:float:
	get:
		return float(empty_count) / count if count > 0 else 0.0
				
var avg_excess_count:float:
	get:
		return float(excess_capacity) / def_capacity_per_count

## What fraction of the total capacity is being used
var utilization:float:
	get:
		return used_capacity / float(total_capacity) if total_capacity > 0 else 1.0 if candidate_unit_count > 0 else 0.0

## What fraction of the candidate units could be put in the total capacity
var coverage:float:
	get:
		if total_capacity > 0 and candidate_unit_count > 0:
			return float(total_capacity) / candidate_unit_count
		elif candidate_unit_count > 0:
			return 0.0
		else: # No units so we have full coverage of nothing
			return 1.0
#endregion

func add_unused_capacity(in_count:int) -> void:
	if in_count <= 0:
		return
	
	count += in_count
	empty_count += in_count
	total_capacity += in_count * def_capacity_per_count
