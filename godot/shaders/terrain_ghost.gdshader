// Ghost version of the terrain surface for pre-modern chapters: today's land surface drawn as a faint,
// hatched reference (Illustrative in those eras).
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, unshaded;

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform vec2 origin_xz;
uniform vec2 size_xz;
uniform vec2 tex_size;
uniform float z_min;
uniform float z_max;
uniform float ghost_alpha = 0.11;

varying vec3 wpos;
varying float vshade;

float height_at(vec2 uv) {
	vec3 c = texture(height_tex, uv).rgb;
	return (c.r * 255.0 * 256.0 + c.g * 255.0) / 65535.0 * (z_max - z_min) + z_min;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = (wp.xz - origin_xz) / size_xz + 0.5 / tex_size;
	VERTEX.y = height_at(uv);
	wpos = vec3(wp.x, VERTEX.y, wp.z);
	vshade = texture(height_tex, uv).b;
}

void fragment() {
	ALBEDO = vec3(0.9, 0.92, 0.95) * (0.5 + 0.5 * vshade);
	ALPHA = ghost_alpha;
}
