#!/usr/bin/env python3
"""Generate project/terrain/terrain_web_shader.gdshader from Terrain3D sources.

Replicates Terrain3DMaterial::_generate_shader_code() for this project's
material settings (levels/terrain_material.tres + Terrain3D defaults), then
patches the region uniforms so the material uniform block fits under the 16KB
GL_MAX_UNIFORM_BLOCK_SIZE enforced by Safari and Chromium on macOS/iOS
(ANGLE-on-Metal). See docs/mac-webgl-terrain-rendering.md for the full story.

Material settings baked into this generator:
  world_background = NONE, texture_filtering = LINEAR_ANISOTROPIC,
  auto_shader / dual_scaling / macro_variation / projection = off,
  tessellation_level = 0, all PBR outputs enabled.

When upgrading the Terrain3D addon, update COMMIT to the new version's commit
hash, rerun this script, and diff the result. If upstream has restructured the
region uniforms (see https://github.com/TokisanGames/Terrain3D/issues/623),
this workaround may no longer be needed.

Usage: python3 cli_tools/generate_terrain_web_shader.py [output_path]
"""
import os
import re
import sys
import urllib.request

# Pin to the commit of the installed addon build (see git log / addon README).
COMMIT = "ff4614c"
BASE_URL = f"https://raw.githubusercontent.com/TokisanGames/Terrain3D/{COMMIT}/src/shaders/"
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(REPO_ROOT, "project", "terrain", "terrain_web_shader.gdshader")

INSERT_FILES = ["samplers.glsl", "backgrounds.glsl", "auto_shader.glsl",
                "dual_scaling.glsl", "overlays.glsl", "displacement.glsl",
                "macro_variation.glsl", "projection.glsl", "debug_views.glsl",
                "pbr_views.glsl", "editor_functions.glsl"]

# Excludes as computed by Terrain3DMaterial::_generate_shader_code() for the
# material settings listed above.
EXCLUDES = [
    # world_background == NONE
    "FLAT_UNIFORMS", "FLAT_FUNCTIONS", "FLAT_VERTEX", "FLAT_FRAGMENT",
    "WORLD_NOISE_UNIFORMS", "WORLD_NOISE_FUNCTIONS", "WORLD_NOISE_VERTEX", "WORLD_NOISE_FRAGMENT",
    # texture_filtering == LINEAR_ANISOTROPIC
    "TEXTURE_SAMPLERS_NEAREST", "TEXTURE_SAMPLERS_NEAREST_ANISOTROPIC", "TEXTURE_SAMPLERS_LINEAR",
    # features disabled
    "AUTO_SHADER_UNIFORMS", "AUTO_SHADER",
    "DUAL_SCALING_UNIFORMS", "DUAL_SCALING", "DUAL_SCALING_CONDITION_0",
    "DUAL_SCALING_CONDITION_1", "DUAL_SCALING_MIX",
    "MACRO_VARIATION_UNIFORMS", "MACRO_VARIATION",
    "PROJECTION",
    # tessellation_level == 0
    "DISPLACEMENT_UNIFORMS", "DISPLACEMENT_FUNCTIONS", "DISPLACEMENT_VERTEX",
    # all PBR outputs enabled
    "OUTPUT_ALBEDO_GREY", "OUTPUT_SPECULAR_NONE",
]


def fetch(fname):
    with urllib.request.urlopen(BASE_URL + fname) as resp:
        return resp.read().decode()


def strip_cpp_raw_string(text):
    """The glsl files are C++ raw-string includes; keep only R"( ... )" content."""
    first = text.index('R"(')
    last = text.rindex(')"')
    body = text[first + 3:last]
    return re.sub(r'\)"\s*R"\(', '', body)  # join adjacent raw string literals


def build_insert_db():
    """Terrain3DMaterial::_parse_shader over all insert files."""
    db = {}
    for f in INSERT_FILES:
        content = strip_cpp_raw_string(fetch(f))
        parsed = content.split("//INSERT:")
        db[f] = parsed[0]
        for chunk in parsed[1:]:
            seg = chunk.split("\n", 1)
            if len(seg) < 2:
                continue
            ident = seg[0].strip()
            if ident and seg[1]:
                db[ident] = seg[1]
    return db


def apply_inserts(main, db):
    """Terrain3DMaterial::_apply_inserts with EXCLUDES."""
    parsed = main.split("//INSERT:")
    shader = parsed[0]
    for chunk in parsed[1:]:
        seg = chunk.split("\n", 1)
        if len(seg) < 2:
            continue
        ident = seg[0].strip()
        if ident and ident not in EXCLUDES and ident in db \
                and not ident.startswith("DEBUG_") and not ident.startswith("EDITOR_"):
            shader += db[ident]
        shader += seg[1]
    return shader


def patch_region_uniforms(shader):
    old_uniforms = """uniform int _region_map_size = 32;
uniform int _region_map[1024];
uniform vec2 _region_locations[1024];"""
    new_uniforms = """// WEB COMPATIBILITY PATCH (see docs/mac-webgl-terrain-rendering.md):
// The stock shader declares `int _region_map[1024]` + `vec2 _region_locations[1024]`,
// which alone occupy 32KB of the material uniform block under std140 layout.
// Safari and Chromium browsers on macOS/iOS (ANGLE-on-Metal) cap
// GL_MAX_UNIFORM_BLOCK_SIZE at 16384 bytes, so shader linking fails and the
// terrain renders as untextured brown. We instead use a 16x16 window of the
// 32x32 region map (region locations -8..7 — this game uses -3..2) populated
// at runtime by terrain/terrain_web_region_map.gd, and cap regions at 128.
const int _SM_REGION_MAP_SIZE = 16;
uniform int _sm_region_map[256]; // filled by terrain_web_region_map.gd
uniform vec2 _region_locations[128]; // filled by Terrain3D core (it sends only the active region count)"""
    assert old_uniforms in shader, "region uniform block not found"
    shader = shader.replace(old_uniforms, new_uniforms)

    old_coord = """	vec2 r_uv = round(uv);
	ivec2 pos = ivec2(floor(r_uv * _region_texel_size)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int layer_index = _region_map[pos.y * _region_map_size + pos.x] * bounds - 1;
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);"""
    new_coord = """	vec2 r_uv = round(uv);
	// WEB COMPATIBILITY PATCH: use the compact 16x16 region map.
	ivec2 pos = ivec2(floor(r_uv * _region_texel_size)) + (_SM_REGION_MAP_SIZE / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_SM_REGION_MAP_SIZE));
	int layer_index = _sm_region_map[(pos.y * _SM_REGION_MAP_SIZE + pos.x) * bounds] * bounds - 1;
	return ivec3(ivec2(mod(r_uv, _region_size)), layer_index);"""
    assert old_coord in shader, "get_index_coord body not found"
    shader = shader.replace(old_coord, new_coord)

    old_uv = """	ivec2 pos = ivec2(floor(uv2)) + (_region_map_size / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_region_map_size));
	int layer_index = _region_map[ pos.y * _region_map_size + pos.x ] * bounds - 1;
	return vec3(uv2 - _region_locations[layer_index], float(layer_index));"""
    new_uv = """	// WEB COMPATIBILITY PATCH: use the compact 16x16 region map.
	ivec2 pos = ivec2(floor(uv2)) + (_SM_REGION_MAP_SIZE / 2);
	int bounds = int(uint(pos.x | pos.y) < uint(_SM_REGION_MAP_SIZE));
	int layer_index = _sm_region_map[ (pos.y * _SM_REGION_MAP_SIZE + pos.x) * bounds ] * bounds - 1;
	return vec3(uv2 - _region_locations[max(layer_index, 0)], float(layer_index));"""
    assert old_uv in shader, "get_index_uv body not found"
    return shader.replace(old_uv, new_uv)


def main():
    db = build_insert_db()
    shader = apply_inserts(strip_cpp_raw_string(fetch("main.glsl")), db)
    shader = patch_region_uniforms(shader)

    leftover = [l for l in shader.splitlines() if "//INSERT:" in l]
    assert not leftover, f"unresolved inserts: {leftover}"
    code_only = "\n".join(l.split("//")[0] for l in shader.splitlines())
    assert not re.search(r"(?<!_sm)_region_map[\[\s]", code_only), "stock _region_map still referenced"
    assert "#define FILTER_METHOD" in shader, "FILTER_METHOD define missing"
    assert "_region_map_size" not in code_only, "_region_map_size still referenced"

    header = f"""// Terrain3D shader override for web (WebGL2 / Compatibility) exports.
// Generated from Terrain3D main @ {COMMIT} sources with this project's material
// settings (world_background=NONE, linear anisotropic filtering, no auto
// shader / dual scaling / macro variation / projection / tessellation), then
// patched to keep the material uniform block under the 16KB
// GL_MAX_UNIFORM_BLOCK_SIZE enforced by Safari and Chromium on macOS/iOS.
// Details: docs/mac-webgl-terrain-rendering.md
// Regenerate with: python3 cli_tools/generate_terrain_web_shader.py
"""
    out = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUT
    with open(out, "w") as f:
        f.write(header + shader.lstrip("\n"))
    print(f"wrote {out} ({len(shader)} chars)")


if __name__ == "__main__":
    main()
