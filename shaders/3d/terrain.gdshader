shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/3d/common.gdshaderinc"

uniform sampler2D art_grass : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_forest : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_sand : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_sand_wet : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_cliff : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_rock : repeat_enable, filter_linear_mipmap;
uniform sampler2D art_earth : repeat_enable, filter_linear_mipmap;
uniform float has_grass = 0.0;
uniform float has_forest = 0.0;
uniform float has_sand = 0.0;
uniform float has_sand_wet = 0.0;
uniform float has_cliff = 0.0;
uniform float has_rock = 0.0;
uniform float has_earth = 0.0;
uniform float art_tile = 640.0;   // world px covered by one texture repeat

varying vec2 v_w;      // world position in cells
varying float v_h;     // height (0..1 field)

float field_h(vec2 w) {
	vec2 wpx = w * CELL_PX;
	float h = texture(height_tex, w / GRID).r;
	float e = h - 0.5;
	float rough = smoothstep(0.02, 0.12, e);
	h += ((nz(wpx / 190.0).g - 0.5) * 0.05 + (nz(wpx / 70.0).a - 0.5) * 0.018) * rough;
	return h;
}

void vertex() {
	vec2 w = VERTEX.xz;
	float h = field_h(w);
	VERTEX.y = max((h - 0.5) * HS, -0.6);
	v_w = w;
	v_h = h;
}

vec3 grass_color(float b) {
	vec3 lush = vec3(0.42, 0.70, 0.22);
	vec3 trop = vec3(0.36, 0.74, 0.30);
	vec3 dry = vec3(0.62, 0.70, 0.27);
	vec3 rock = vec3(0.47, 0.45, 0.41);
	vec3 c = mix(lush, trop, smoothstep(0.0, 0.34, b));
	c = mix(c, dry, smoothstep(0.34, 0.67, b));
	return mix(c, rock, smoothstep(0.67, 1.0, b));
}

vec3 forest_color(float b) {
	vec3 lush = vec3(0.07, 0.33, 0.13);
	vec3 trop = vec3(0.03, 0.40, 0.24);
	vec3 dry = vec3(0.20, 0.40, 0.12);
	vec3 rock = vec3(0.32, 0.31, 0.30);
	vec3 c = mix(lush, trop, smoothstep(0.0, 0.34, b));
	c = mix(c, dry, smoothstep(0.34, 0.67, b));
	return mix(c, rock, smoothstep(0.67, 1.0, b));
}

void fragment() {
	vec2 w = v_w;
	vec2 wpx = w * CELL_PX;
	vec2 uv = w / GRID;
	vec2 tx = 1.0 / GRID;
	float t = TIME;
	vec4 hs = texture(height_tex, uv);
	float h = v_h;
	float e = h - 0.5;
	if (e < -0.006) {
		discard;
	}
	float biome = clamp(hs.b, 0.0, 1.0);

	// Normal from the height field, plus fine bump on rock.
	float hL = field_h(w - vec2(0.5, 0.0));
	float hR = field_h(w + vec2(0.5, 0.0));
	float hU = field_h(w - vec2(0.0, 0.5));
	float hD = field_h(w + vec2(0.0, 0.5));
	vec3 n_w = normalize(vec3((hL - hR) * HS, 1.0, (hU - hD) * HS));
	float slope = 1.0 - n_w.y;
	float rock_amt = smoothstep(0.22, 0.42, slope) + smoothstep(0.38, 0.5, e);
	vec2 bump = vec2(nz(wpx / 22.0 + vec2(0.02, 0.0)).a - nz(wpx / 22.0 - vec2(0.02, 0.0)).a, nz(wpx / 22.0 + vec2(0.0, 0.02)).a - nz(wpx / 22.0 - vec2(0.0, 0.02)).a);
	n_w = normalize(n_w + vec3(bump.x, 0.0, bump.y) * 3.0 * clamp(rock_amt, 0.15, 1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz);

	float sand_w = 0.03 + (nz(wpx / 120.0).b - 0.5) * 0.02;
	vec3 grass = grass_color(biome);
	float canopy_a = nz(wpx / 26.0).a;
	float canopy_b = nz(wpx / 63.0 + 0.37).g;
	float blobs = smoothstep(0.38, 0.72, canopy_a * 0.62 + canopy_b * 0.46);
	float forest_amt = hs.g * smoothstep(sand_w + 0.015, sand_w + 0.08, e) * (1.0 - smoothstep(0.30, 0.42, e));
	vec3 fcol = forest_color(biome);
	// Painted textures, when supplied, replace the procedural colours but keep
	// the biome tint so islands still differ.
	vec2 tuv = wpx / art_tile;
	vec3 tint = mix(vec3(1.0), vec3(1.0, 0.95, 0.7), smoothstep(0.34, 0.67, biome) * 0.5);
	if (has_grass > 0.5) {
		grass = mix(grass, texture(art_grass, tuv).rgb * tint, 0.88);
	}
	if (has_earth > 0.5) {
		grass = mix(grass, texture(art_earth, tuv * 1.1).rgb, smoothstep(0.45, 0.8, biome) * 0.8);
	}
	if (has_forest > 0.5) {
		vec3 ft = texture(art_forest, tuv * 1.3).rgb;
		fcol = mix(fcol, ft, 0.9);
		blobs = 0.65;
	}
	vec3 ground = mix(grass * (0.85 + 0.3 * canopy_b), mix(fcol * 0.6, fcol * 1.2, blobs), clamp(forest_amt * 1.6, 0.0, 1.0));
	if (has_forest > 0.5) {
		ground = mix(grass * (0.85 + 0.3 * canopy_b), fcol, clamp(forest_amt * 1.6, 0.0, 1.0));
	}

	// Cliffs and stone with strata.
	float strata = 0.5 + 0.5 * sin((h * 120.0) + nz(wpx / 300.0).r * 6.0);
	float chunks = smoothstep(0.3, 0.7, nz(wpx / 55.0).a * 0.6 + nz(wpx / 130.0).g * 0.5);
	vec3 rock = mix(vec3(0.34, 0.31, 0.29), vec3(0.62, 0.57, 0.5), strata * 0.6 + chunks * 0.4);
	rock = mix(rock, rock * vec3(1.2, 0.92, 0.75), smoothstep(0.4, 0.8, nz(wpx / 900.0).g));
	float cracks = smoothstep(0.9, 1.0, nz(wpx / 150.0).b);
	rock = mix(rock, vec3(0.1, 0.09, 0.09), cracks * 0.35);
	if (has_cliff > 0.5 || has_rock > 0.5) {
		vec3 rt = rock;
		if (has_rock > 0.5) rt = texture(art_rock, tuv * 1.4).rgb;
		if (has_cliff > 0.5) rt = mix(rt, texture(art_cliff, tuv * 1.2).rgb, smoothstep(0.2, 0.5, slope));
		rock = mix(rock, rt, 0.92);
	}
	ground = mix(ground, rock, clamp(rock_amt, 0.0, 1.0));

	// Beach.
	float swash = 0.010 + 0.007 * sin(t * 0.7 + nz(wpx / 1300.0).r * 9.0);
	vec3 dry_sand = vec3(0.94, 0.86, 0.63) * (0.94 + 0.1 * nz(wpx / 60.0).a);
	vec3 wet_sand = dry_sand * vec3(0.7, 0.66, 0.6);
	if (has_sand > 0.5) dry_sand = texture(art_sand, tuv * 1.6).rgb;
	if (has_sand_wet > 0.5) wet_sand = texture(art_sand_wet, tuv * 1.6).rgb;
	else if (has_sand > 0.5) wet_sand = dry_sand * vec3(0.7, 0.66, 0.6);
	vec3 sand = mix(wet_sand, dry_sand, smoothstep(swash * 0.4, swash + 0.016, e));
	vec3 col = mix(sand, ground, smoothstep(sand_w, sand_w + 0.02, e));
	col = mix(col, col * vec3(0.5, 0.7, 0.7), 1.0 - smoothstep(-0.02, 0.0, e)); // submerged slope

	float fa = 0.0;
	vec3 fc = fog_of_war(col, w, t);
	ALBEDO = fc;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
}
