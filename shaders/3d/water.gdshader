shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/3d/common.gdshaderinc"

varying vec2 v_w;
varying float v_wave;
varying vec2 v_grad;

// Sum of directional sine waves. Cell units; returns height, writes gradient.
float waves(vec2 p, float t, float amp, out vec2 g) {
	vec2 wd = normalize(g_wind + vec2(0.0001, 0.0));
	vec2 d0 = wd;
	vec2 d1 = vec2(wd.y, -wd.x) * 0.6 + wd * 0.8;
	vec2 d2 = vec2(-wd.y, wd.x) * 0.7 + wd * 0.7;
	vec2 d3 = wd * 0.5 - vec2(wd.y, -wd.x) * 0.85;
	float y = 0.0;
	g = vec2(0.0);
	float k, a, ph;
	k = 0.55; a = 1.0 * amp; ph = k * dot(d0, p) - sqrt(k * 9.8 * 0.18) * t;
	y += a * sin(ph); g += a * k * cos(ph) * d0;
	k = 0.9; a = 0.6 * amp; ph = k * dot(d1, p) - sqrt(k * 9.8 * 0.18) * t;
	y += a * sin(ph); g += a * k * cos(ph) * d1;
	k = 1.5; a = 0.35 * amp; ph = k * dot(d2, p) - sqrt(k * 9.8 * 0.18) * t;
	y += a * sin(ph); g += a * k * cos(ph) * d2;
	k = 2.4; a = 0.2 * amp; ph = k * dot(d3, p) - sqrt(k * 9.8 * 0.18) * t;
	y += a * sin(ph); g += a * k * cos(ph) * d3;
	return y;
}

float wave_amp(vec2 w) {
	float h = texture(height_tex, w / GRID).r;
	float deep = smoothstep(0.0, 0.14, 0.5 - h);
	return (0.05 + g_waves * 0.5) * mix(0.15, 1.0, deep);
}

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 g;
	float y = waves(w, TIME, wave_amp(w), g);
	VERTEX.y += y;
	v_w = w;
	v_wave = y;
	v_grad = g;
}

void fragment() {
	float t = TIME;
	vec2 w = v_w;
	vec2 wpx = w * CELL_PX;
	vec2 uv = w / GRID;
	vec2 wd = normalize(g_wind + vec2(0.0001, 0.0));
	float ws = clamp(length(g_wind), 0.0, 1.2);
	float h = texture(height_tex, uv).r;
	vec4 n_big = nz(wpx / 1300.0);
	vec4 n_mid = nz(wpx / 330.0);
	vec4 n_fine = nz(wpx / 120.0);
	h += (n_fine.g - 0.5) * 0.016 + (n_mid.r - 0.5) * 0.01;
	float depth = max(0.5 - h, 0.0);

	// Colour by depth, tuned toward a bright turquoise lagoon and deep navy sea.
	vec3 c_shallow = vec3(0.30, 0.86, 0.78);
	vec3 c_mid = vec3(0.09, 0.58, 0.74);
	vec3 c_deep = vec3(0.03, 0.25, 0.52);
	vec3 c_abyss = vec3(0.02, 0.13, 0.36);
	vec3 col = mix(c_shallow, c_mid, smoothstep(0.0, 0.10, depth));
	col = mix(col, c_deep, smoothstep(0.08, 0.26, depth));
	col = mix(col, c_abyss, smoothstep(0.30, 0.40, depth));
	float shallow_m = 1.0 - smoothstep(0.0, 0.14, depth);

	// Reef and seagrass patches, sandy ripples on the bottom.
	float reef = smoothstep(0.5, 0.72, n_big.g * 0.65 + n_mid.b * 0.25 + n_fine.a * 0.2) * shallow_m;
	col = mix(col, vec3(0.03, 0.36, 0.32), reef * 0.75);
	float ripples = smoothstep(0.35, 0.65, nz(wpx / 58.0).g);
	col = mix(col, col * vec3(1.14, 1.1, 0.95) + vec3(0.03, 0.05, 0.02), ripples * shallow_m * shallow_m * 0.55);
	col = mix(col, vec3(0.82, 0.9, 0.72), (1.0 - smoothstep(0.0, 0.05, depth)) * 0.4);

	// Caustics.
	float sun = (1.0 - g_storm * 0.7) * (1.0 - g_night * 0.8) * (1.0 - g_fog * 0.5);
	vec2 q1 = wpx / 95.0 + vec2(t * 0.020, -t * 0.014);
	vec2 q2 = wpx / 66.0 + vec2(-t * 0.016, t * 0.011);
	float cs = smoothstep(0.80, 1.02, nz(q1).b * 0.55 + nz(q2).b * 0.55);
	col += vec3(0.55, 0.95, 0.9) * cs * shallow_m * 0.3 * sun;

	// Normal: analytic swell plus two scrolling micro-ripple layers.
	vec3 n_w = normalize(vec3(-v_grad.x, 1.0, -v_grad.y));
	vec2 r1 = wpx / 70.0 - wd * t * (0.01 + 0.02 * ws);
	vec2 r2 = wpx / 31.0 + vec2(wd.y, -wd.x) * t * 0.03;
	vec2 e1 = vec2(nz(r1 + vec2(0.01, 0.0)).r - nz(r1 - vec2(0.01, 0.0)).r, nz(r1 + vec2(0.0, 0.01)).r - nz(r1 - vec2(0.0, 0.01)).r);
	vec2 e2 = vec2(nz(r2 + vec2(0.02, 0.0)).g - nz(r2 - vec2(0.02, 0.0)).g, nz(r2 + vec2(0.0, 0.02)).g - nz(r2 - vec2(0.0, 0.02)).g);
	n_w = normalize(n_w + vec3(e1.x + e2.x * 0.6, 0.0, e1.y + e2.y * 0.6) * (0.9 + g_waves * 1.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_w, 0.0)).xyz);

	// Foam on the shore, with rolling surf lines.
	float rolling = sin(depth * 78.0 - t * 1.8 + n_mid.r * 6.0);
	float band = smoothstep(0.5, 0.95, rolling) * (1.0 - smoothstep(0.012, 0.085, depth));
	float edge_w = 0.016 + 0.008 * sin(t * 0.9 + n_big.r * 8.0);
	float edge = 1.0 - smoothstep(0.0, edge_w, depth);
	float breakup = smoothstep(0.18, 0.55, nz(wpx / 49.0 + vec2(0.0, t * 0.01)).a + 0.2 * rolling);
	float foam = clamp(max(band * 0.85 * breakup, edge * (0.75 + 0.25 * breakup)), 0.0, 1.0);
	// Whitecaps on steep crests once the sea gets up.
	float crest = smoothstep(0.55, 1.0, length(v_grad) * 1.4 + v_wave * 0.8);
	float caps = crest * smoothstep(0.35, 0.8, g_waves) * smoothstep(0.35, 0.7, nz(wpx / 40.0 + wd * t * 0.05).a + 0.25);
	foam = max(foam, caps * 0.9);
	col = mix(col, vec3(0.97, 0.99, 1.0), foam * 0.9);

	// Rain rings.
	if (g_rain > 0.02) {
		vec2 cell = floor(wpx / 40.0);
		vec2 f = fract(wpx / 40.0) - 0.5;
		float hsh = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		vec2 off = (vec2(fract(hsh * 13.7), fract(hsh * 5.9)) - 0.5) * 0.5;
		float ph = fract(t * (0.7 + hsh * 0.7) + hsh * 7.3);
		float ring = smoothstep(0.05, 0.0, abs(length(f - off) - ph * 0.3)) * (1.0 - ph) * (1.0 - ph);
		col += vec3(0.8, 0.9, 1.0) * ring * step(hsh, g_rain * 0.85) * 0.3;
	}

	// Weather grade.
	float sh_cloud = smoothstep(0.50, 0.74, nz(wpx / 2800.0 + wd * t * 0.0022).g * 0.6 + nz(wpx / 1500.0 - wd * t * 0.003).r * 0.45);
	col *= 1.0 - 0.22 * sh_cloud * g_clouds;
	col *= mix(vec3(1.0), vec3(1.07, 0.97, 0.84), g_warm);
	col *= 1.0 - 0.22 * g_storm - 0.07 * g_rain;
	col = mix(vec3(luma3(col)), col, g_sat);

	vec3 fc = fog_of_war(col, w, t);
	ALBEDO = fc * 0.62;
	EMISSION = fc * (0.5 + 0.35 * shallow_m);
	ROUGHNESS = mix(0.14, 0.9, foam);
	SPECULAR = 0.55 * (1.0 - foam);
	METALLIC = 0.0;
}
