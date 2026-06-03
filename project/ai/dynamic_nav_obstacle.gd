class_name DynamicNavObstacle extends Node3D

const ComponentName:StringName = "DynamicNavObstacle"

@export_flags_avoidance
var default_avoidance_layers:int

@export
var affects_unit_classes:Array[Unit.UnitClass]

@export
var affect_only_enemy_team:bool

@export
var circle_bounds_vertices:int = 16

@export
var extra_bounds_padding:float = 0.0

@export
var is_dynamic:bool

@onready 
var nav_obstacle: NavigationObstacle3D = %NavigationObstacle3D

var _team_asset_root:Node3D

#region Component Registration

static func get_component(node: Node, required:bool = true) -> DynamicNavObstacle:
	return Components.get_component(ComponentName, node, required) as DynamicNavObstacle
		
func _enter_tree() -> void:
	_team_asset_root = Groups.get_parent_in_group(self, Groups.TeamAsset)
	if not _team_asset_root:
		push_warning("%s: Added to not team asset root - will not be updated to fit collision bounds!" % name)
	
	Components.add_component(ComponentName, self)

func _exit_tree() -> void:
	Components.remove_component(ComponentName, self)
#endregion

func affects(unit:Unit) -> bool:
	if not is_instance_valid(unit):
		return false
		
	var nav_agent:NavigationAgent3D = Groups.get_child_with_type(unit, NavigationAgent3D)
	if not nav_agent:
		return false
	
	return nav_obstacle.avoidance_layers & nav_agent.avoidance_mask != 0
	
func _ready() -> void:
	if _team_asset_root and affect_only_enemy_team:
		var team_component := TeamComponent.get_component(_team_asset_root, false)
		if team_component:
			team_component.team_changed.connect(_refresh_avoidance_layers.unbind(1))
	
	_set_team_asset_collision_layer()	
	_refresh_avoidance_layers()
	
	if _team_asset_root:
		_build_obstacle_bounds.call_deferred()

func _set_team_asset_collision_layer() -> void:
	var physics_body:PhysicsBody3D = _team_asset_root as PhysicsBody3D
	if not physics_body:
		return
	
	physics_body.collision_layer |= Collisions.Layers.dynamic_obstacle
		
func _refresh_avoidance_layers() -> void:
	var teams:PackedInt32Array
	if _team_asset_root and affect_only_enemy_team:
		var team_component := TeamComponent.get_component(_team_asset_root, false)
		if team_component:
			teams = Avoidance.get_enemy_teams(team_component.team)
		
	nav_obstacle.avoidance_layers = Avoidance.get_avoidance_team_layer_mask(default_avoidance_layers, affects_unit_classes, teams)

func _build_obstacle_bounds() -> void:
	if not _team_asset_root.has_method("get_bounds") or "bounds_type" not in _team_asset_root:
		push_warning("%s: Team Asset root '%s' does not have the required bounds functionality - will not be updated to fit collision bounds!" % [name, _team_asset_root.name])
		return
		
	# Vertices are in local space
	var bounds:Bounds = Bounds.new(_team_asset_root.get_bounds(), _team_asset_root.bounds_type)
	
	var vertices:PackedVector3Array
	var height:float = 0.0
	var radius:float = 0.0
	
	match bounds.type:
		Bounds.Type.AABB:
			var aabb:AABB = bounds.aabb
			if is_dynamic:
				radius = MathUtils.grid_vector(aabb.size).length() * 0.5 + extra_bounds_padding
			else:
				vertices = _build_rectangle(aabb)
			height = aabb.size.y
		Bounds.Type.SPHERE_INSCRIBED:
			var sphere:BoundingSphere = bounds.inscribed_sphere
			if is_dynamic:
				radius = sphere.radius + extra_bounds_padding
			else:
				vertices = _build_circle(sphere)
			height = sphere.radius * 2.0
		Bounds.Type.SPHERE_CIRCUMSCRIBED:
			var sphere:BoundingSphere = bounds.circumscribed_sphere
			height = sphere.radius * 2.0
			
			if is_dynamic:
				radius = sphere.radius + extra_bounds_padding
			else:
				vertices = _build_circle(sphere)

	if vertices:
		# Zero out y coordinate to avoid warnings
		for vertex in vertices:
			vertex.y = 0.0
		nav_obstacle.vertices = vertices
	
	if height > 0:
		nav_obstacle.height = height
	
	if radius > 0:
		nav_obstacle.radius = radius
	
func _build_rectangle(bounds:AABB) -> PackedVector3Array:
	if extra_bounds_padding > 0:
		bounds = bounds.grow(extra_bounds_padding)
		
	# Make sure it is CCW as we want to push the agents out of the bounds not into
	# We are only supporting 2D agents (what GameUnitNavigation) is using so y-axis ignored
	var vertices:PackedVector3Array
	vertices.resize(4)
	
	# TODO: The corner constants are wrong and should be fixed. From testing this gives the correct CCW winding order
	# as "left" and "right" are reversed
	vertices[0] = bounds.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_LEFT)
	vertices[1] = bounds.get_endpoint(Collisions.AABBCorner.BACK_BOTTOM_RIGHT)
	vertices[2] = bounds.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_RIGHT)
	vertices[3] = bounds.get_endpoint(Collisions.AABBCorner.FRONT_BOTTOM_LEFT)

	return vertices

func _build_circle(bounds:BoundingSphere) -> PackedVector3Array:
	if extra_bounds_padding > 0:
		bounds.expand(extra_bounds_padding)
		
	var vertices:PackedVector3Array
	vertices.resize(circle_bounds_vertices)
	
	var angle_stride:float = TAU / circle_bounds_vertices
	var center:Vector3 = bounds.center
	var radius:float = bounds.radius
	
	var angle:float = 0.0
	for i in circle_bounds_vertices:
		var heading:Vector2 = Vector2.from_angle(angle) * radius
		var vertex:Vector3 = center + Vector3(heading.x, 0.0, heading.y)
		
		vertices[i] = vertex
		angle += angle_stride
	
	return vertices
