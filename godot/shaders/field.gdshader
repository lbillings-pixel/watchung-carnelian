// Temperature / pH field for Chapter 4: vertical gradient hot-acidic (bottom) -> cool-alkaline (top),
// shifted by the mixing ratio. Illustrative shape; the ranges are the paper's.
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform float y_bottom = 0.0;
uniform float y_top = 100.0;
uniform float mix = 0.5;        // 0 hydrothermal-dominated .. 1 meteoric-dominated
uniform float strength = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = clamp((wpos.y - y_bottom) / (y_top - y_bottom), 0.0, 1.0);
	// position of the mixing front moves down as meteoric water dominates
	float front = mix(0.82, 0.45, mix);
	float hot = 1.0 - smoothstep(front - 0.25, front + 0.1, u);
	vec3 col = mix(vec3(0.25, 0.5, 1.0), vec3(1.0, 0.3, 0.05), hot);
	float band = 0.08 * step(0.5, fract(u * 24.0));
	ALBEDO = col + band;
	ALPHA = 0.16 * strength;
}
