shader_type canvas_item;
render_mode unshaded;

// The whole archipelago in one quad: water, shallows, surf, beaches, forests,
// rock, cloud shadows, rain ripples and the fog of war. Everything is driven
// by a small height field (R = height, G = forest, B = biome) plus a tileable
// noise atlas, so there are no tiles and no seams.

global uniform vec2 g_wind;
global uniform float g_rain;
global uniform float g_storm;
global uniform float g_fog;
global uniform float g_night;
global uniform float g_waves;
global uniform float g_sat;
global uniform float g_warm;
global uniform float g_clouds;
global uniform float g_quality;
global uniform vec4 g_ship; // xy = world position, z = vision radius

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D explored_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(10800.0, 19200.0);
uniform vec2 grid_size = vec2(450.0, 800.0);
uniform float reveal_all = 0.0;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec4 nz(vec2 p) {
	return texture(noise_tex, p);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
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

vec3 sand_color(float b) {
	return mix(vec3(0.94, 0.86, 0.63), vec3(0.62, 0.58, 0.5), smoothstep(0.7, 1.0, b));
}

void fragment() {
	float t = TIME;
	vec2 uv = wpos / world_size;
	vec2 texel = 1.0 / grid_size;
	vec2 wd = normalize(g_wind + vec2(0.0001, 0.0));
	float ws = clamp(length(g_wind), 0.0, 1.2);

	vec4 hs = texture(height_tex, uv);
	vec4 n_big = nz(wpos / 1300.0);
	vec4 n_mid = nz(wpos / 330.0);
	vec4 n_fine = nz(wpos / 120.0);

	float h = hs.r + (n_fine.g - 0.5) * 0.016 + (n_mid.r - 0.5) * 0.01;
	float biome = clamp(hs.b, 0.0, 1.0);
	vec3 col;

	if (h > 0.5) {
		// ------------------------------------------------------------ land
		float e = h - 0.5;
		float shade = 0.5;
		float slope = 0.0;
		float ao = 0.0;
		float cast = 0.0;
		vec2 light = normalize(vec2(-0.55, -0.83));
		if (g_quality > 0.5) {
			float hx = texture(height_tex, uv + vec2(texel.x, 0.0)).r - texture(height_tex, uv - vec2(texel.x, 0.0)).r;
			float hy = texture(height_tex, uv + vec2(0.0, texel.y)).r - texture(height_tex, uv - vec2(0.0, texel.y)).r;
			shade = clamp(0.5 - (hx + hy) * 2.6, 0.0, 1.0);
			slope = length(vec2(hx, hy));
			if (g_quality > 1.5) {
				float avg = (texture(height_tex, uv + vec2(texel.x * 2.0, 0.0)).r + texture(height_tex, uv - vec2(texel.x * 2.0, 0.0)).r + texture(height_tex, uv + vec2(0.0, texel.y * 2.0)).r + texture(height_tex, uv - vec2(0.0, texel.y * 2.0)).r) * 0.25;
				ao = clamp((avg - hs.r) * 7.0, 0.0, 0.2);
				for (int k = 1; k <= 4; k++) {
					float hk = texture(height_tex, uv + light * texel * float(k) * 1.4).r;
					cast = max(cast, step(hs.r + float(k) * 0.012, hk));
				}
			}
		} else {
			shade = clamp(0.62 - e * 0.5, 0.0, 1.0);
		}

		float sand_w = 0.028 + (n_fine.b - 0.5) * 0.02;
		vec3 grass = grass_color(biome);
		// Painterly canopy: two noise scales thresholded into soft blobs.
		float canopy_a = nz(wpos / 26.0).a;
		float canopy_b = g_quality > 0.5 ? nz(wpos / 63.0 + 0.37).g : 0.5;
		float blobs = smoothstep(0.38, 0.72, canopy_a * 0.62 + canopy_b * 0.46);
		float blobs_l = smoothstep(0.38, 0.72, nz((wpos + light * 7.0) / 26.0).a * 0.62 + canopy_b * 0.46);
		float rim = clamp(blobs - blobs_l, -1.0, 1.0);
		float forest_amt = hs.g * smoothstep(sand_w + 0.015, sand_w + 0.09, e) * (1.0 - smoothstep(0.30, 0.42, e));
		vec3 fcol = forest_color(biome);
		vec3 trees = mix(fcol * 0.7, fcol * 1.45, blobs);
		trees += vec3(0.16, 0.2, 0.05) * max(rim, 0.0) * 1.2;
		trees *= 1.0 - 0.35 * max(-rim, 0.0);
		vec3 ground = mix(grass * (0.88 + 0.24 * canopy_b), trees, clamp(forest_amt * 1.5, 0.0, 1.0));

		// Rock on the heights.
		float rock_w = smoothstep(0.34, 0.44, e + (n_fine.r - 0.5) * 0.1 + (n_mid.g - 0.5) * 0.06);
		// Steep ground becomes cliff.
		rock_w = max(rock_w, smoothstep(0.11, 0.2, slope + (n_fine.a - 0.5) * 0.03) * smoothstep(0.06, 0.12, e) * 0.85);
		vec3 rock = mix(vec3(0.46, 0.43, 0.4), vec3(0.64, 0.62, 0.6), smoothstep(0.25, 0.46, e));
		float chunks = smoothstep(0.36, 0.7, nz(wpos / 26.0).a * 0.55 + nz(wpos / 58.0).g * 0.5);
		float cracks = smoothstep(0.82, 0.98, nz(wpos / 64.0).b);
		float strata = 0.5 + 0.5 * sin((wpos.y + n_mid.r * 160.0) / 7.0);
		rock = mix(rock * 0.55, rock * 1.15, chunks) * (0.85 + 0.25 * strata);
		rock = mix(rock, rock * vec3(1.15, 0.95, 0.8), smoothstep(0.4, 0.8, n_big.g));
		rock = mix(rock, vec3(0.12, 0.1, 0.1), cracks * 0.8);
		shade = mix(shade, clamp(shade * 1.5 - 0.2, 0.0, 1.0), rock_w);
		ground = mix(ground, rock, rock_w);
		float snow_w = smoothstep(0.46, 0.52, e + (n_fine.g - 0.5) * 0.05) * (1.0 - smoothstep(0.0, 0.4, biome));
		ground = mix(ground, vec3(0.94, 0.96, 0.98), snow_w);

		// Beach.
		float swash = 0.010 + 0.007 * sin(t * 0.7 + n_big.r * 9.0);
		vec3 dry_sand = sand_color(biome) * (0.94 + 0.1 * n_fine.a);
		vec3 wet_sand = dry_sand * vec3(0.72, 0.68, 0.62);
		vec3 sand = mix(wet_sand, dry_sand, smoothstep(swash * 0.4, swash + 0.016, e));
		col = mix(sand, ground, smoothstep(sand_w, sand_w + 0.02, e));
		col *= 0.66 + shade * 0.68;
		col *= 1.0 - ao - cast * 0.24;
		col = mix(col, col * vec3(0.85, 0.92, 1.08), cast * 0.5);
		col *= 1.12;

		// Soft dark rim where land meets surf, for depth.
		col *= 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.02, e));
	} else {
		// ----------------------------------------------------------- water
		float depth = 0.5 - h;
		vec3 c_shallow = vec3(0.32, 0.82, 0.78);
		vec3 c_mid = vec3(0.12, 0.58, 0.77);
		vec3 c_deep = vec3(0.035, 0.26, 0.55);
		vec3 c_abyss = vec3(0.03, 0.18, 0.44);
		col = mix(c_shallow, c_mid, smoothstep(0.0, 0.11, depth));
		col = mix(col, c_deep, smoothstep(0.09, 0.28, depth));
		col = mix(col, c_abyss, smoothstep(0.30, 0.40, depth));
		float shallow_m = 1.0 - smoothstep(0.0, 0.14, depth);

		// Island shadows fall across the water.
		if (g_quality > 0.5) {
			vec2 lw = normalize(vec2(-0.55, -0.83));
			float shw = 0.0;
			for (int k = 1; k <= 3; k++) {
				float hk = texture(height_tex, uv + lw * texel * float(k) * 2.2).r;
				shw += step(0.512, hk) * (1.0 - float(k) * 0.24);
			}
			col *= 1.0 - clamp(shw, 0.0, 1.0) * 0.32;
		}
		// Ripples in the seabed sand.
		float seabed = smoothstep(0.35, 0.65, nz(wpos / 58.0 + vec2(t * 0.002, 0.0)).g);
		col = mix(col, col * vec3(1.12, 1.1, 0.95) + vec3(0.03, 0.05, 0.02), seabed * shallow_m * shallow_m * 0.5);
		// Sunlit sand under the shallows.
		col = mix(col, vec3(0.80, 0.88, 0.70), (1.0 - smoothstep(0.0, 0.045, depth)) * 0.38);
		// Reef and seagrass patches: darker teal-green blotches in the lagoons.
		float reef = smoothstep(0.5, 0.72, n_big.g * 0.65 + n_mid.b * 0.25 + n_fine.a * 0.2) * shallow_m;
		col = mix(col, vec3(0.04, 0.38, 0.34), reef * 0.7);
		col *= 1.0 - 0.1 * smoothstep(0.55, 0.8, n_mid.g) * shallow_m;

		// Swell.
		float flow = t * (0.008 + 0.018 * ws);
		vec2 p1 = wpos / 300.0 - wd * flow;
		vec2 p2 = wpos / 140.0 - vec2(wd.y, -wd.x) * flow * 1.4 + 0.31;
		vec4 w1 = nz(p1);
		vec4 w2 = g_quality > 0.5 ? nz(p2) : vec4(0.5);
		float wave = w1.r * 0.5 + w2.g * 0.3 + w1.g * 0.2;
		col *= 1.0 + (wave - 0.5) * (0.34 + g_waves * 0.5);
		float crest = smoothstep(0.58 - g_waves * 0.1, 0.86, wave);
		col += vec3(0.5, 0.75, 0.8) * crest * (0.05 + 0.1 * g_waves);

		float sun = (1.0 - g_storm * 0.7) * (1.0 - g_night * 0.8) * (1.0 - g_fog * 0.5);
		if (g_quality > 0.5) {
			// Caustic net in the shallows.
			vec2 q1 = wpos / 95.0 + vec2(t * 0.020, -t * 0.014);
			vec2 q2 = wpos / 66.0 + vec2(-t * 0.016, t * 0.011);
			float c = nz(q1).b * 0.55 + nz(q2).b * 0.55;
			float lines = smoothstep(0.80, 1.02, c);
			col += vec3(0.55, 0.95, 0.9) * lines * shallow_m * 0.16 * sun;
			// Sun glints.
			float g1 = nz(wpos / 46.0 + vec2(t * 0.05, t * 0.07)).a;
			float g2 = nz(wpos / 31.0 - vec2(t * 0.04, t * 0.03) + 0.5).a;
			float glint = smoothstep(0.90, 0.985, min(g1, g2) + wave * 0.1);
			col += vec3(1.0, 0.95, 0.8) * glint * (0.5 + g_waves) * sun;
		}

		// Whitecaps once the sea gets up.
		if (g_waves > 0.4) {
			float cap = w2.r * 0.55 + w1.b * 0.25 + (nz(wpos / 52.0 + wd * t * 0.03).a - 0.5) * 0.34;
			cap = smoothstep(0.76 - g_waves * 0.1, 0.9, cap);
			col = mix(col, vec3(0.9, 0.96, 1.0), cap * clamp((g_waves - 0.4) * 1.6, 0.0, 1.0) * 0.75);
		}

		// Surf and shoreline foam.
		float rolling = sin(depth * 78.0 - t * 1.8 + n_mid.r * 6.0);
		float band = smoothstep(0.5, 0.95, rolling) * (1.0 - smoothstep(0.012, 0.085, depth));
		float edge_w = 0.016 + 0.008 * sin(t * 0.9 + n_big.r * 8.0);
		float edge = 1.0 - smoothstep(0.0, edge_w, depth);
		float breakup = smoothstep(0.18, 0.55, nz(wpos / 49.0 + vec2(0.0, t * 0.01)).a + 0.2 * rolling);
		float foam = clamp(max(band * 0.8 * breakup, edge * (0.7 + 0.3 * breakup)), 0.0, 1.0);
		col = mix(col, vec3(0.96, 0.99, 1.0), foam * 0.88);

		// Rain ripples.
		if (g_rain > 0.02 && g_quality > 0.5) {
			vec2 cell = floor(wpos / 40.0);
			vec2 f = fract(wpos / 40.0) - 0.5;
			float hsh = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
			vec2 off = (vec2(fract(hsh * 13.7), fract(hsh * 5.9)) - 0.5) * 0.5;
			float ph = fract(t * (0.7 + hsh * 0.7) + hsh * 7.3);
			float ring = smoothstep(0.05, 0.0, abs(length(f - off) - ph * 0.3)) * (1.0 - ph) * (1.0 - ph);
			col += vec3(0.8, 0.9, 1.0) * ring * step(hsh, g_rain * 0.85) * 0.3;
		}
	}

	// ------------------------------------------------------------ weather grade
	float sh_cloud = smoothstep(0.50, 0.74, nz(wpos / 2800.0 + wd * t * 0.0022).g * 0.6 + (g_quality > 0.5 ? nz(wpos / 1500.0 - wd * t * 0.003).r * 0.45 : 0.22));
	col *= 1.0 - 0.24 * sh_cloud * g_clouds;
	col *= mix(vec3(1.0), vec3(1.07, 0.97, 0.84), g_warm);
	col *= 1.0 - 0.22 * g_storm - 0.07 * g_rain;
	col = mix(vec3(luma(col)), col, g_sat * 1.08);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.3);

	// ------------------------------------------------------------ fog of war
	vec2 dd = wpos - g_ship.xy;
	float dist = length(dd);
	float vr = g_ship.z;
	float wob = (n_mid.g - 0.5) * 0.28 * vr;
	float visible = 1.0 - smoothstep(vr * 0.58, vr * 1.0 + wob, dist);
	float ex = max(texture(explored_tex, uv).r, reveal_all);
	float fogc = nz(wpos / 760.0 + wd * t * 0.007).r * 0.6 + (g_quality > 0.5 ? nz(wpos / 310.0 - wd * t * 0.011 + 0.2).g * 0.4 : 0.2);
	float edge_d = min(min(wpos.x, wpos.y), min(world_size.x - wpos.x, world_size.y - wpos.y));
	float rev = max(ex, visible) * smoothstep(140.0, 520.0, edge_d + (fogc - 0.5) * 240.0);
	rev = smoothstep(0.2, 0.8, rev + (fogc - 0.5) * 0.3);

	vec3 remembered = mix(col, vec3(luma(col)) * vec3(0.78, 0.9, 1.05), 0.38) * 0.8;
	vec3 shown = mix(remembered, col, visible);
	vec3 murk = mix(vec3(0.045, 0.1, 0.16), vec3(0.17, 0.27, 0.36), fogc);
	murk += vec3(0.05, 0.07, 0.08) * smoothstep(0.6, 0.9, nz(wpos / 210.0 + wd * t * 0.01).a) * 0.5;
	col = mix(murk, shown, rev);

	COLOR = vec4(col, 1.0);
}
