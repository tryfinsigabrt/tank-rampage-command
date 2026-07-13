@tool
extends Terrain3D
## Feeds the compact region map uniform used by terrain_web_shader.gdshader.
##
## @tool is REQUIRED: the override shader shows no regions until this script
## fills _sm_region_map, so without it the terrain would be invisible in the
## editor viewport. Running as a tool script also live-updates the uniform
## (via region_map_changed) when regions are added/removed while editing.
##
## The stock Terrain3D shader declares `int _region_map[1024]` +
## `vec2 _region_locations[1024]`, putting the material uniform block far over
## the 16KB GL_MAX_UNIFORM_BLOCK_SIZE that Safari and Chromium browsers enforce
## on macOS/iOS (ANGLE-on-Metal), so the shader fails to link and the terrain
## renders as flat brown. The override shader instead declares a 16x16 window
## of the 32x32 region grid (region locations -8..7), which this script
## populates from the loaded terrain data using the same packing the C++ core
## uses for the full map (index = (y + size/2) * size + (x + size/2), value =
## region id + 1, 0 = no region).

const REGION_MAP_SIZE := 16 # must match _SM_REGION_MAP_SIZE in terrain_web_shader.gdshader
const REGION_MAP_HALF := 8 # locations -8..7 are representable
const MAX_REGIONS := 128 # must match _region_locations[] size in terrain_web_shader.gdshader


func _ready() -> void:
	if data:
		data.region_map_changed.connect(_update_region_map_uniform)
	_update_region_map_uniform.call_deferred()


func _update_region_map_uniform() -> void:
	if material == null or data == null:
		return
	var locations := data.get_region_locations()
	if locations.size() > MAX_REGIONS:
		push_warning("Terrain has %d regions; only %d fit the web-compatible shader" % [locations.size(), MAX_REGIONS])
	var region_map := PackedInt32Array()
	region_map.resize(REGION_MAP_SIZE * REGION_MAP_SIZE)
	for i in locations.size():
		var loc: Vector2i = locations[i]
		var x := loc.x + REGION_MAP_HALF
		var y := loc.y + REGION_MAP_HALF
		if x < 0 or x >= REGION_MAP_SIZE or y < 0 or y >= REGION_MAP_SIZE:
			push_warning("Terrain region %s is outside the web-compatible region map window" % loc)
			continue
		region_map[y * REGION_MAP_SIZE + x] = i + 1
	# Terrain3DMaterial.set_shader_param() ignores private (underscore-prefixed)
	# uniforms, so set the parameter on the material directly, the same way the
	# Terrain3D core feeds its own private uniforms.
	RenderingServer.material_set_param(material.get_material_rid(), &"_sm_region_map", region_map)
