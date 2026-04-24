class_name NodePlacementSpawnerResource extends Resource

@export
var to_spawn:PackedScene

@export
var max_slope_angle_deg:float = 15.0

@export_flags_3d_physics
var collision_mask:int = Collisions.CompositeMasks.any_asset
