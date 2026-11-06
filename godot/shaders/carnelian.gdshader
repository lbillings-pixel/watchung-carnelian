// Carnelian: translucent, faintly banded orange-red chalcedony with light leaking through its edges and a rough,
// waxy surface.  Cheap: no subsurface pass, just a wrapped diffuse, a back-light term and a fresnel rim.
// Model coordinates are divided by `size` so the banding and grain scale with the piece.  Presentation only.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.78, 0.20, 0.05, 1.0);
uniform vec4 light_color : source_color = vec4(0.98, 0.52, 0.16, 1.0);
uniform float seed = 0.0;
uniform float size = 1.0;          // radius of the piece in model units (metres)
uniform float translucency = 0.7;  // 0..1 light through the edges
uniform float grain = 1.0;         // surface roughness relief
uniform float band_freq = 5.0;
uniform float sparkle = 0.0;       // glint and glow strength (1 for pieces seen en masse)
uniform float sparkle_soft = 0.0;  // 1 for close-ups (round 10): wider, softer glints, slower flicker and breathing

varying vec3 mp;

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
	mp = VERTEX / max(size, 1.0e-9) + vec3(seed);
}

void fragment() {
	float n1 = vnoise(mp * 2.2);
	float n2 = vnoise(mp * 6.5);
	float n3 = vnoise(mp * 26.0);
	// gentle concentric-ish banding, warped by the low noise
	float band = 0.5 + 0.5 * sin((mp.x * 0.8 + mp.y * 1.3 + mp.z * 0.6) * band_freq + 4.0 * n1);
	vec3 col = mix(base_color.rgb, light_color.rgb, 0.55 * band + 0.3 * (n2 - 0.5));
	// occasional paler patches (chalcedony is rarely uniform)
	col = mix(col, vec3(0.95, 0.72, 0.45), smoothstep(0.72, 0.9, n1) * 0.35);
	ALBEDO = col;
	// rough, waxy surface: perturb the normal with high-frequency noise
	vec3 g = vec3(vnoise(mp * 40.0 + 11.0), vnoise(mp * 40.0 + 23.0), vnoise(mp * 40.0 + 37.0)) - 0.5;
	NORMAL = normalize(NORMAL + g * 0.22 * grain);
	ROUGHNESS = 0.42 + 0.2 * n3 * grain;
	SPECULAR = 0.5;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	EMISSION = light_color.rgb * (fr * 0.30 * translucency + 0.03);
	if (sparkle > 0.0) {
		// glints: a sparse high-frequency noise thresholded against the view direction, so points of light wander
		// across the piece as the camera moves; plus a slow breathing glow
		vec3 vd = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
		float gl = vnoise(mp * mix(55.0, 30.0, sparkle_soft) + vd * mix(6.0, 2.5, sparkle_soft) + vec3(seed));
		float lo = mix(0.80, 0.66, sparkle_soft);   // soft: a wide, gentle shoulder instead of a hard-edged point
		float hi = mix(0.93, 0.98, sparkle_soft);
		float flick = 0.6 + 0.4 * sin(TIME * mix(5.0, 1.4, sparkle_soft) + seed * 9.0);
		float glint = smoothstep(lo, hi, gl) * flick;
		float breathe = 0.5 + 0.5 * sin(TIME * mix(2.2, 0.7, sparkle_soft) + seed * 4.0);
		float gain = mix(1.4, 0.45, sparkle_soft);
		float glow = mix(0.22, 0.10, sparkle_soft);
		EMISSION += (vec3(1.0, 0.9, 0.7) * glint * gain + light_color.rgb * breathe * glow) * sparkle;
	}
}

void light() {
	// wrapped diffuse (light bleeds a little past the terminator) + light transmitted through the piece
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.55) / 1.55, 0.0, 1.0);
	DIFFUSE_LIGHT += wrap * ATTENUATION * LIGHT_COLOR / PI;
	float back = clamp(dot(-NORMAL, LIGHT), 0.0, 1.0) * clamp(dot(-VIEW, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += light_color.rgb * back * translucency * 0.6 * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(clamp(dot(NORMAL, h), 0.0, 1.0), 42.0) * 0.35 * ATTENUATION * LIGHT_COLOR / PI;
}
