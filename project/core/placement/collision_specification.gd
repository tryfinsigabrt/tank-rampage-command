class_name CollisionSpecification extends Resource

enum TeamMaskType
{
	None,
	Same,
	Enemy
}

@export_flags_3d_physics
var base_collision_mask:int = 0

@export
var team_mask_type:TeamMaskType = TeamMaskType.None

@export
var collision_shape:Shape3D

## Specify true if want to only allow spawning if a collision occurs
## By default a collision causes the criteria to fail.
@export
var invert_result:bool

func get_collision_mask(team:int) -> int:
	if team_mask_type == TeamMaskType.None:
		return base_collision_mask
		
	# Update the team mask based on the parameter team
	var team_mask:int = _get_team_mask(team)
	var mask:int = MathUtils.update_mask(base_collision_mask, Collisions.CompositeMasks.all_teams, team_mask)
	return mask
	
func _get_team_mask(team:int) -> int:
	match team_mask_type:
		TeamMaskType.Same: return Collisions.Layers.team_masks.get(team, 0)
		TeamMaskType.Enemy: return Collisions.enemy_team_mask(team)
		_ : return 0
