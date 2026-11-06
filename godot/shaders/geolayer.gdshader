// Subsurface layer slab.  Cut by today's terrain on the GPU (fragments above ground are discarded),
// by the movable cross-section plane, and styled by certainty tier:
//   tier 0 Observed     -> solid
//   tier 1 Inferred     -> translucent
//   tier 2 Illustrative -> ghosted with diagonal hatching
// Back faces are shaded flat so a cut through a slab reads as a solid cut surface.
// glow: incandescent tint for a layer that is still molten (eruption chapters; cosmetic cue only).
// highlighted / pulse: tour emphasis.
shader_type spatial;
render_mode cull_disabled, depth_draw_always, blend_mix;

uniform vec4 albedo : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform int tier = 0;
uniform bool tier_styling = true;
uniform float layer_alpha = 1.0;
uniform bool clip_to_terrain = true;
uniform bool cut_enabled = false;
uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);
uniform float vexag = 1.0;
uniform bool highlighted = false;
uniform float pulse = 0.0;             // 0..1 animated emphasis (set by Main each frame while highlighted)
uniform float glow = 0.0;              // 0..1 incandescence (chapter 3/5 while the layer is "erupting")
uniform float grain_amount = 1.0;      // 0 switches the rock grain off (diagnostics)
uniform bool keep_underside = false;   // the lowest slab keeps its underside (nothing lies beneath it)
uniform bool eroded_ghost = false;     // draw the part ABOVE today's ground as a ghost instead of discarding
uniform bool clip_to_box = false;      // limit the drawn extent to a box (used by the untilted depositional stack)
uniform vec3 box_min = vec3(-1.0e9);
uniform vec3 box_max = vec3(1.0e9);

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform sampler2D bedrock_tex : filter_nearest, repeat_disable;
uniform float erosion_level = -1.0e9;         // Chapter 6: ground not yet eroded below this (flat paleo-surface)
uniform float erosion_level_valley = -1.0e9;  // same, over the Feltville (valley forms first)
uniform vec2 origin_xz;
uniform vec2 size_xz;
uniform vec2 tex_size;
uniform float z_min;
uniform float z_max;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // shared 3-octave noise (NoiseTex.gd)

varying vec3 wpos;
varying vec3 wnormal;

// 3-D-ish noise from the 2-D texture: the plan view and a side view averaged, so cut faces vary too
float noise3(vec3 p, float scale) {
	return 0.5 * (texture(noise_tex, p.xz * scale).r + texture(noise_tex, vec2(p.x + p.z, p.y) * scale + 0.5).r);
}

float height_at(vec2 xz) {
	vec2 uv = (xz - origin_xz) / size_xz + 0.5 / tex_size;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return -1.0e9;   // outside the DEM: treat as 'no ground' so the model's outer walls are not drawn above it
	}
	vec3 c = texture(height_tex, uv).rgb;
	return (c.r * 255.0 * 256.0 + c.g * 255.0) / 65535.0 * (z_max - z_min) + z_min;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Stacked slabs share their contact planes exactly. Seen from inside a cut, a slab's underside (a back face)
	// and the top of the slab below (a front face) sit at the same depth and z-fight: a dotted band at 1 km (the
	// depth buffer resolves ~0.2 m there). So the horizontal-ish faces are never drawn as back faces: the cut shows
	// the neighbouring slab's front face instead, which is the same surface. The lowest slab keeps its floor.
	if (!FRONT_FACING && abs(wnormal.y) > 0.5 && !(keep_underside && wnormal.y < 0.0)) {
		discard;
	}
	if (clip_to_box && (wpos.x < box_min.x || wpos.x > box_max.x || wpos.z < box_min.z || wpos.z > box_max.z || wpos.y < box_min.y || wpos.y > box_max.y)) {
		discard;
	}
	float ground = height_at(wpos.xz);
	vec2 uv = (wpos.xz - origin_xz) / size_xz + 0.5 / tex_size;
	int bid = int(texture(bedrock_tex, uv).r * 255.0 + 0.5);
	float lvl = (bid == 3) ? erosion_level_valley : erosion_level;   // 3 = Feltville
	ground = max(ground, lvl);
	bool above = wpos.y > ground * vexag;
	if (clip_to_terrain && above && !eroded_ghost) {
		discard;
	}
	if (cut_enabled && dot(wpos, cut_plane.xyz) > cut_plane.w) {
		discard;
	}
	float a = layer_alpha;
	vec3 col = albedo.rgb;
	if (tier_styling) {
		if (tier == 1) {
			a *= 0.55;
		} else if (tier == 2) {
			float hatch = step(0.5, fract((wpos.x + wpos.y * 1.7 + wpos.z) / 12.0));
			a *= mix(0.18, 0.45, hatch);
		}
	}
	if (above && eroded_ghost) {
		float hatch = step(0.5, fract((wpos.x - wpos.y * 1.3 + wpos.z) / 25.0));
		a *= mix(0.08, 0.22, hatch);
	}
	// rock grain (polish pass): fine brightness variation so cut faces and slabs do not read as flat paint
	float grain = noise3(wpos, 0.06);   // mipmapped: no aliasing at a distance
	col *= 0.90 + 0.2 * grain * grain_amount;
	float crack = 0.0;
	if (glow > 0.0) {
		// molten: a darkening crust over incandescent material; the cracks between crust plates narrow and dim
		// as the layer cools (glow -> 0), with a slow flicker (cosmetic cue only)
		float n = noise3(wpos + vec3(0.0, TIME * 0.4, 0.0), 0.0045) * 0.6 + texture(noise_tex, wpos.xz * 0.016 + 0.23).r * 0.3 + texture(noise_tex, wpos.xz * 0.07 + 0.61).r * 0.1;
		float edge = 0.62 - 0.22 * glow;
		crack = 1.0 - smoothstep(edge - 0.05, edge + 0.08, n);
		crack *= 0.85 + 0.15 * sin(TIME * 3.0 + wpos.x * 0.3 + wpos.z * 0.2);
		vec3 crust = vec3(0.10, 0.04, 0.03) * (0.6 + 0.8 * grain);
		vec3 hot = mix(crust, vec3(1.0, 0.52, 0.10), crack);
		col = mix(col, hot, glow);
		a = max(a, glow * 0.97);
	}
	if (highlighted) {
		col = mix(col, vec3(1.0, 0.85, 0.2), 0.3 + 0.25 * pulse);
		a = max(a, 0.6 + 0.3 * pulse);
	}
	if (!FRONT_FACING) {
		col *= 0.72;
	}
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	if (glow > 0.0) {
		EMISSION = vec3(1.0, 0.42, 0.06) * glow * (0.12 + 1.5 * crack);
	}
}
