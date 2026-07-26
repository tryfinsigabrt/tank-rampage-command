extends Node3D

@export
var vfx_scene:PackedScene

## Sets the spawn container for the vfx scene
## By default the vfx scene is spawned in the parent of the team asset (if defined) else a child of this node
@export_node_path("Node")
var spawn_container:NodePath

@export
var scene_properties:Dictionary[StringName, Variant]

var _container:Node
var _team_asset:Node3D

func _ready() -> void:
	assert(vfx_scene, "Vfx Scene not set!")

	var team_asset:Node = Groups.get_parent_in_group(self, Groups.TeamAsset)
	assert(team_asset)
	if not team_asset:
		queue_free()
		return
		
	_team_asset = team_asset
	_container = get_node_or_null(spawn_container)
	
	if not _container:
		_container = team_asset.get_parent()
		if not _container:
			_container = self
			
	HealthStat.connect_died_signal(team_asset, _spawn_death_scene)	
	
func _spawn_death_scene() -> void:
	# Only spawn if team asset is visible in tree (not obscured by fog of war)
	if not vfx_scene or not _team_asset.is_visible_in_tree():
		return
	
	var instance:Node = vfx_scene.instantiate()
	
	# Set extra properties on instance before adding to scene
	for key in scene_properties:
		if key in instance:
			instance.set(key, scene_properties[key])
			
	_container.add_child(instance)
	
	if instance is Node3D:
		instance.global_position = global_position	
