// Terrain surface: a flat grid displaced on the GPU from the packed 16-bit heightmap.
// Coloured by mapped bedrock unit (Observed), surficial class (Observed) or plain hillshade.
// cover_mode 1 draws the same grid lowered by the cover-thickness field (the modelled top of bedrock under
// colluvium / alluvium / till; Illustrative taper of Observed extents and maxima, ASSUMPTIONS A-G8).
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D height_tex : filter_nearest, repeat_disable;   // R,G = hi/lo byte, B = hillshade
uniform sampler2D bedrock_tex : filter_nearest, repeat_disable;  // unit id in R
uniform sampler2D surf_tex : filter_nearest, repeat_disable;
uniform sampler2D cover_tex : filter_nearest, repeat_disable;    // cover thickness, cover_scale_m per level
uniform float cover_scale_m = 0.2;
uniform int cover_mode = 0;          // 0 land surface, 1 bedrock top under the cover
uniform vec3 deplete_center = vec3(0.0);
uniform float deplete_radius = 0.0;  // chapter 7 'source used up' scenario: cover thins around a site
uniform float deplete_scale = 1.0;
uniform vec2 origin_xz;      // world x,z of the north-west texel corner
uniform vec2 size_xz;        // extents in metres
uniform vec2 tex_size;       // texels
uniform float cell = 4.0;
uniform float z_min;
uniform float z_max;
uniform int color_mode = 3;  // 0 bedrock, 1 surficial, 2 hillshade only, 3 natural (textured, polish pass)
uniform vec4 bedrock_colors[16];
uniform vec4 surf_colors[16];
uniform float unit_opacity = 0.85;
uniform bool cut_enabled = false;
uniform vec4 cut_plane = vec4(0.0, 1.0, 0.0, 1.0e9);   // discard where dot(p.xyz, n) > d
uniform float vexag = 1.0;   // vertical exaggeration (applied by parent scale; passed for cut tests)
uniform vec3 highlight_center = vec3(0.0);
uniform float highlight_radius = 0.0;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform float pulse = 0.0;
uniform float erosion_level = -1.0e9;         // Chapter 6: hide ground still buried below the paleo-surface
uniform float erosion_level_valley = -1.0e9;
uniform float surface_alpha = 1.0;            // < 1 when the cover skin is shown (so the bedrock top reads through)
// detail patches (polish pass): fine 1 m meshes around the brook sites replace the coarse grid inside their box
uniform bool is_patch = false;
uniform int patch_n = 0;
uniform vec4 patch_boxes[4];                  // x0, z0, x1, z1 (world)
// brook channel carved into the surface along the mapped stream near the sites (Illustrative, A-G20)
uniform int channel_n = 0;
uniform vec4 channel_segs[64];                // x0, z0, x1, z1
uniform vec4 channel_bbox = vec4(0.0);        // x0, z0, x1, z1 of all segments (grown by the half-width)
uniform float channel_depth = 1.0;
uniform float channel_halfwidth = 3.5;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // shared 3-octave noise (NoiseTex.gd)

varying vec3 wpos;
varying vec2 vuv;
varying float vshade;
varying float vcover;
varying vec3 vnorm;
varying float vslope;

float height_at(vec2 uv) {
	vec3 c = texture(height_tex, uv).rgb;
	return (c.r * 255.0 * 256.0 + c.g * 255.0) / 65535.0 * (z_max - z_min) + z_min;
}

float channel_at(vec2 xz) {
	if (xz.x < channel_bbox.x || xz.x > channel_bbox.z || xz.y < channel_bbox.y || xz.y > channel_bbox.w) {
		return 0.0;   // nowhere near the channel: skip the segment loop (most of the 3 million terrain vertices)
	}
	float best = 1.0e9;
	for (int i = 0; i < channel_n; i++) {
		vec2 a = channel_segs[i].xy;
		vec2 b = channel_segs[i].zw;
		vec2 ab = b - a;
		float t = clamp(dot(xz - a, ab) / max(dot(ab, ab), 1.0e-6), 0.0, 1.0);
		best = min(best, distance(xz, a + ab * t));
	}
	// parabolic cross-section, deepest on the centreline
	float u = clamp(best / channel_halfwidth, 0.0, 1.0);
	return channel_depth * (1.0 - u * u);
}

float cover_at(vec2 uv, vec2 xz) {
	float t = texture(cover_tex, uv).r * 255.0 * cover_scale_m;
	if (deplete_radius > 0.0) {
		int sid = int(texture(surf_tex, uv).r * 255.0 + 0.5);
		if (sid == 2 || sid == 3) {   // basalt colluvium, alluvium
			float d = distance(xz, deplete_center.xz);
			t *= mix(deplete_scale, 1.0, smoothstep(deplete_radius * 0.6, deplete_radius, d));
		}
	}
	return t;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = (wp.xz - origin_xz) / size_xz + 0.5 / tex_size;
	vuv = uv;
	float e = height_at(uv);
	if (channel_n > 0) {
		e -= channel_at(wp.xz);
	}
	vcover = cover_at(uv, wp.xz);
	if (cover_mode == 1) {
		e -= vcover;
	}
	VERTEX.y = e;
	vec2 du = vec2(cell / size_xz.x, 0.0);
	vec2 dv = vec2(0.0, cell / size_xz.y);
	float hx = height_at(uv + du) - height_at(uv - du);
	float hz = height_at(uv + dv) - height_at(uv - dv);
	NORMAL = normalize(vec3(-hx * vexag, 2.0 * cell, -hz * vexag));
	vnorm = NORMAL;
	vslope = 1.0 - normalize(vec3(-hx, 2.0 * cell, -hz)).y;
	wpos = vec3(wp.x, e * vexag, wp.z);
	vshade = texture(height_tex, uv).b;
}

void fragment() {
	if (cut_enabled && dot(wpos, cut_plane.xyz) > cut_plane.w) {
		discard;
	}
	if (!is_patch) {
		for (int i = 0; i < patch_n; i++) {
			vec4 b = patch_boxes[i];
			if (wpos.x > b.x && wpos.x < b.z && wpos.z > b.y && wpos.z < b.w) {
				discard;   // a detail patch draws this ground
			}
		}
	}
	int bid0 = int(texture(bedrock_tex, vuv).r * 255.0 + 0.5);
	float lvl = (bid0 == 3) ? erosion_level_valley : erosion_level;
	if (wpos.y / vexag < lvl) {
		discard;
	}
	if (cover_mode == 1 && vcover < 0.05) {
		discard;   // no cover here: the bedrock top IS the land surface
	}
	float shade = 0.45 + 0.55 * vshade;
	vec3 base = vec3(0.86, 0.84, 0.80);
	float alpha = surface_alpha;
	if (cover_mode == 1) {
		// bedrock top under the cover: bedrock unit colour, darkened, with a faint hatch (modelled surface)
		vec3 c = bedrock_colors[clamp(bid0, 0, 15)].rgb;
		float hatch = step(0.5, fract((wpos.x + wpos.z) / 6.0));
		base = mix(c * 0.72, c * 0.64, hatch);
		alpha = 1.0;
	} else if (color_mode == 0) {
		int id = bid0;
		vec3 c = bedrock_colors[clamp(id, 0, 15)].rgb;
		base = mix(base, c, id > 0 ? unit_opacity : 0.0);
	} else if (color_mode == 1) {
		int id = int(texture(surf_tex, vuv).r * 255.0 + 0.5);
		vec3 c = surf_colors[clamp(id, 0, 15)].rgb;
		base = mix(base, c, id > 0 ? unit_opacity : 0.0);
	} else if (color_mode == 3) {
		// natural: wooded uplands, greener floodplains, bare rock on steep ground, noise for texture, and a faint
		// tint of the mapped bedrock unit so the geology stays readable (polish pass)
		int sid = int(texture(surf_tex, vuv).r * 255.0 + 0.5);
		float n1 = texture(noise_tex, wpos.xz * 0.0012).r;          // ~80 m features
		float n2 = texture(noise_tex, wpos.xz * 0.009 + 0.37).r;    // ~11 m
		float n3 = texture(noise_tex, wpos.xz * 0.05 + 0.71).r;     // ~2 m
		vec3 forest = vec3(0.27, 0.36, 0.20);
		vec3 meadow = vec3(0.47, 0.52, 0.27);
		vec3 soil = vec3(0.44, 0.36, 0.26);
		vec3 rock = vec3(0.40, 0.40, 0.39);
		vec3 wet = vec3(0.32, 0.40, 0.30);
		vec3 c = forest;
		if (sid == 3 || sid == 4) {
			c = mix(meadow, forest, 0.35 + 0.4 * n2);      // alluvium, terraces: open floodplain
		} else if (sid == 5) {
			c = wet;                                        // swamp
		} else if (sid == 2 || sid == 13) {
			c = mix(forest, soil, 0.35 + 0.3 * n2);         // colluvium, talus
		} else if (sid >= 7 && sid <= 10) {
			c = mix(forest, soil, 0.2 + 0.25 * n2);         // tills, lake deposits
		} else if (sid == 14) {
			c = rock;
		}
		c = mix(c, rock, smoothstep(0.28, 0.55, vslope));
		c *= 0.80 + 0.3 * n1 + 0.14 * (n3 - 0.5);
		if (bid0 > 0) {
			c = mix(c, bedrock_colors[clamp(bid0, 0, 15)].rgb, 0.14);
		}
		base = c;
	}
	if (highlight_radius > 0.0) {
		float d = distance(wpos.xz, highlight_center.xz);
		float ring = smoothstep(highlight_radius * 0.9, highlight_radius, d) * (1.0 - smoothstep(highlight_radius, highlight_radius * (1.1 + 0.1 * pulse), d));
		base = mix(base, highlight_color.rgb, ring * (0.7 + 0.3 * pulse));
	}
	ALBEDO = base * shade;
	if (!FRONT_FACING) {
		ALBEDO *= 0.55;   // underside, seen from below ground
	}
	ALPHA = alpha;
	ROUGHNESS = (color_mode == 3) ? 0.9 - 0.25 * smoothstep(0.28, 0.55, vslope) : 0.95;
	SPECULAR = 0.1;
}
