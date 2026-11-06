// Heat haze above molten lava (polish pass): faint, additive, slowly rising warm streaks in a slab over the
// hottest growing layer. `strength` 0..1 is the chapter's incandescence; nothing is drawn at 0. Cosmetic only.
// (Screen-space refraction is not used: the layer slabs are transparent and so absent from the screen copy.)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float strength = 0.0;
uniform float y_base = 0.0;      // world y of the lava top: the haze fades out with height above it
uniform float y_extent = 25.0;

varying vec3 wpos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((wpos.y - y_base) / y_extent, 0.0, 1.0);
	float fade = (1.0 - h) * smoothstep(0.0, 0.08, h);
	float s = strength * fade;
	if (s <= 0.002) {
		discard;
	}
	vec3 q = vec3(wpos.x * 0.05, wpos.y * 0.18 - TIME * 1.1, wpos.z * 0.05);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.7 + 5.0) * 0.4;
	float streak = smoothstep(0.55, 0.85, n);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);   // stronger seen edge-on through the slab
	ALBEDO = vec3(1.0, 0.55, 0.2) * streak * s * (0.10 + 0.12 * rim);
	ALPHA = 1.0;
}
