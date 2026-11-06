// Glowing shell used by the guided tour's chapter introductions to point at one entity at a time.
// The mesh is re-drawn pushed outward along its normals by `margin` (world metres), unlit and additive, lit only
// where it is seen edge-on (fresnel), so it reads as a bright pulsing rim at the silhouette and edges of boxes,
// spheres, pebbles and slabs, even translucent ones.  Layers on a cut face use a frame drawn by
// Volumes.gd instead (a shell would wash the whole cut face).  Presentation only (ASSUMPTIONS A-G17).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, unshaded, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform float margin = 2.0;          // outward push, world metres (scaled by the caller to the entity size)
uniform float pulse = 0.0;           // 0..1 (set each frame)
uniform float strength = 1.0;
uniform bool cut_enabled = false;
uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);
uniform bool clip_to_box = false;
uniform vec3 box_min = vec3(-1.0e9);
uniform vec3 box_max = vec3(1.0e9);
uniform bool clip_to_terrain = false;
uniform float vexag = 1.0;
uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform vec2 origin_xz;
uniform vec2 size_xz;
uniform vec2 tex_size;
uniform float z_min;
uniform float z_max;
uniform float erosion_level = -1.0e9;

varying vec3 wpos;
varying vec3 wnormal;

float height_at(vec2 xz) {
	vec2 uv = (xz - origin_xz) / size_xz + 0.5 / tex_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return -1.0e9;
	}
	vec3 c = texture(height_tex, uv).rgb;
	return (c.r * 255.0 * 256.0 + c.g * 255.0) / 65535.0 * (z_max - z_min) + z_min;
}

void vertex() {
	vec3 n = normalize(NORMAL);
	VERTEX += n * margin;
	wpos = VERTEX;
	wnormal = n;
}

void fragment() {
	if (clip_to_box && (wpos.x < box_min.x || wpos.x > box_max.x || wpos.z < box_min.z || wpos.z > box_max.z)) {
		discard;
	}
	if (cut_enabled && dot(wpos, cut_plane.xyz) > cut_plane.w) {
		discard;
	}
	if (clip_to_terrain) {
		float ground = max(height_at(wpos.xz), erosion_level);
		if (wpos.y > ground * vexag + margin * 1.5) {
			discard;
		}
	}
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
	float rim = pow(1.0 - abs(dot(normalize(wnormal), vdir)), 3.0);
	float a = (0.03 + 1.1 * rim) * (0.55 + 0.45 * pulse) * strength;
	ALBEDO = color.rgb * a;
	ALPHA = 1.0;
}
