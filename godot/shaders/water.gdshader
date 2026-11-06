// Brook water (polish pass).  Cheap tricks only, no hydraulics: two scrolling noise layers perturb the normal,
// the scene behind is refracted through the screen texture and tinted by the water depth read from the depth
// texture, a fresnel term mixes in the sky, and foam / a wetted edge appear where the water is shallow.
// `turbidity` (0 clear .. 1 muddy flood) and `speed` are driven by the chapter scrubber.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.12, 0.26, 0.30, 1.0);   // deep-water tint
uniform vec4 sky_color : source_color = vec4(0.70, 0.78, 0.86, 1.0);
uniform float turbidity = 0.0;
uniform float flow_dir = 0.0;      // radians, direction the water travels
uniform float speed = 1.0;
uniform float ripple_scale = 1.0;  // metres per ripple cell
uniform float depth_scale = 1.0;   // metres over which the water turns opaque (small for a brook)
uniform float foam_width = 0.35;   // metres of shallow water that read as foam / wet edge
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // shared 3-octave noise (NoiseTex.gd)

varying vec3 wpos;

float vnoise(vec2 x) {
	return texture(noise_tex, x * 0.1).r;   // one ripple cell ~ a tenth of a tile
}

float surf(vec2 p, vec2 d, float t) {
	// two octaves travelling with the flow, one slow cross-ripple set
	return 0.6 * vnoise(p * 1.0 - d * t * 0.9) + 0.3 * vnoise(p * 2.3 - d * t * 1.6 + 3.1) + 0.2 * vnoise(p * 4.0 + vec2(-d.y, d.x) * t * 0.4);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = vec2(cos(flow_dir), sin(flow_dir));
	float t = TIME * speed;
	vec2 p = mod(wpos.xz, 1024.0) / ripple_scale;   // wrap far from the origin so the noise keeps its precision
	float e = 0.02 * ripple_scale;
	float h0 = surf(p, d, t);
	float hx = surf(p + vec2(e, 0.0), d, t) - h0;
	float hz = surf(p + vec2(0.0, e), d, t) - h0;
	float amp = 0.6 + 1.2 * turbidity;
	vec3 n = normalize(vec3(-hx * amp, e * 2.2, -hz * amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// water depth from the depth buffer (opaque scene behind this fragment)
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, dz);
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float scene_z = -vp.z / vp.w;
	float my_z = -VERTEX.z;
	float wd = max(scene_z - my_z, 0.0);
	// refraction of what lies under the surface
	vec2 off = n.xz * (0.035 * (1.0 - 0.8 * turbidity)) * clamp(wd / depth_scale, 0.1, 1.0);
	vec3 refr = texture(screen_tex, clamp(SCREEN_UV + off, vec2(0.001), vec2(0.999))).rgb;
	float dfac = 1.0 - exp(-wd / max(depth_scale, 1.0e-4) * 2.5);
	vec3 body = mix(refr, color.rgb, 0.15 + 0.7 * dfac);
	vec3 muddy = vec3(0.50, 0.38, 0.24);
	body = mix(body, muddy * (0.85 + 0.3 * h0), turbidity);
	float fr = 0.04 + 0.6 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(body, sky_color.rgb, fr * (1.0 - 0.5 * turbidity));
	// foam: the wetted edge in shallow water, plus streaks that grow with the flood
	float edge = 1.0 - smoothstep(0.0, foam_width, wd);
	float streak = smoothstep(0.76, 0.92, vnoise(p * 3.0 - d * t * 2.4) * 0.6 + vnoise(p * 7.0 + d * t * 1.1) * 0.4) * (0.05 + 0.28 * turbidity);
	float foam = clamp(edge * 0.45 + streak, 0.0, 1.0);
	col = mix(col, vec3(0.92, 0.93, 0.9), foam);
	ALBEDO = col;
	ALPHA = clamp(smoothstep(0.0, foam_width * 0.25, wd) * (0.85 + 0.15 * turbidity) + foam * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.22 + 0.3 * turbidity;   // calmer sun sparkle (round 6)
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
