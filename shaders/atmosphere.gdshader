shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// One full-screen pass for everything in the air: night darkness with lantern
// light cut out of it, weather fog, rain streaks, lightning and a vignette.
// Output is premultiplied: alpha darkens what is below, rgb adds light/fog.

global uniform vec2 g_wind;
global uniform float g_rain;
global uniform float g_storm;
global uniform float g_fog;
global uniform float g_night;
global uniform vec4 g_cam;  // xy = camera centre in world, z = zoom
global uniform vec4 g_ship; // xy = ship world position, z = vision radius
global uniform float g_quality;

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 view_px = vec2(1920.0, 1080.0);
uniform vec4 lights[8];       // xy = screen px, z = radius px, w = intensity
uniform vec4 light_cols[8];   // rgb colour
uniform vec4 beam = vec4(0.0); // xy = screen px, z = angle, w = intensity
uniform float flash = 0.0;
uniform float fade = 0.0;      // 0..1 mist wipe used for scene transitions
uniform vec3 night_col = vec3(0.025, 0.06, 0.17);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

vec4 nz(vec2 p) {
	return texture(noise_tex, p);
}

void fragment() {
	vec2 px = UV * view_px;
	float t = TIME;
	vec2 wpos = g_cam.xy + (px - view_px * 0.5) / g_cam.z;
	vec2 wd = normalize(g_wind + vec2(0.0001, 0.0));
	vec2 ship_px = (g_ship.xy - g_cam.xy) * g_cam.z + view_px * 0.5;
	float vis_px = g_ship.z * g_cam.z;

	vec3 add = vec3(0.0);
	float a = 0.0;

	// ---------------------------------------------------------------- night
	float dark = g_night * 0.72 + g_storm * 0.14;
	float lm = 0.0;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float r = lights[i].z;
		if (r > 1.0) {
			float q = clamp(1.0 - length(px - lights[i].xy) / r, 0.0, 1.0);
			float f = q * q * (3.0 - 2.0 * q) * lights[i].w;
			lm += f;
			glow += light_cols[i].rgb * f * f;
		}
	}
	if (beam.w > 0.0) {
		vec2 d = px - beam.xy;
		float len = length(d);
		float ang = atan(d.y, d.x);
		float da1 = abs(atan(sin(ang - beam.z), cos(ang - beam.z)));
		float da2 = abs(atan(sin(ang - beam.z - 3.14159), cos(ang - beam.z - 3.14159)));
		float da = min(da1, da2);
		float cone = smoothstep(0.2, 0.02, da * (1.0 + 0.0008 * len));
		float f = cone * (1.0 - smoothstep(200.0, 2600.0, len)) * smoothstep(20.0, 160.0, len) * beam.w;
		lm += f * 0.8;
		glow += vec3(1.0, 0.93, 0.7) * f * 0.55;
	}
	lm = clamp(lm, 0.0, 1.0);
	float night_a = dark * (1.0 - lm * 0.78);
	float lights_on = clamp(g_night + g_storm * 0.35 + g_fog * 0.25, 0.0, 1.0);
	add += night_col * night_a + glow * 0.45 * lights_on + vec3(0.9, 0.55, 0.2) * lm * dark * 0.1;
	a += night_a;

	// -------------------------------------------------------------- vignette
	vec2 vc = (UV - 0.5) * vec2(1.35, 1.0);
	float vg = smoothstep(0.45, 1.05, length(vc)) * (0.16 + 0.18 * g_storm + 0.16 * g_night);
	add += vec3(0.0, 0.012, 0.04) * vg;
	a += vg * (1.0 - a);

	// ------------------------------------------------------------------- fog
	float fog_d = g_fog;
	if (fog_d > 0.01) {
		float cl = nz(wpos / 1150.0 + wd * t * 0.012).r * 0.55 + nz(wpos / 430.0 - wd * t * 0.021).g * 0.45;
		float clearing = smoothstep(vis_px * 0.2, vis_px * 1.0, length(px - ship_px));
		float fa = clamp(fog_d * mix(0.14, 1.0, clearing) * (0.5 + 0.9 * cl), 0.0, 0.93);
		vec3 fog_col = mix(vec3(0.74, 0.8, 0.85), vec3(0.1, 0.14, 0.24), g_night);
		fog_col = mix(fog_col, vec3(0.38, 0.42, 0.48), g_storm * 0.8);
		add = add * (1.0 - fa) + fog_col * fa;
		a = a * (1.0 - fa) + fa;
	}

	// ------------------------------------------------------------------ rain
	if (g_rain > 0.01 && g_quality > 0.5) {
		float slant = 0.22 + g_wind.x * 0.18;
		float rain_a = 0.0;
		for (int layer = 0; layer < 2; layer++) {
			float sc = layer == 0 ? 9.0 : 15.0;
			float seed = layer == 0 ? 3.0 : 17.0;
			vec2 r = vec2(px.x + px.y * slant, px.y);
			float col = floor(r.x / sc);
			float h1 = hash11(col + seed);
			if (h1 < g_rain * 0.85) {
				float speed = (layer == 0 ? 1.25 : 0.95) * (0.8 + 0.5 * h1);
				float yy = fract(r.y / (layer == 0 ? 420.0 : 560.0) + t * speed + h1 * 37.0);
				float len = layer == 0 ? 0.11 : 0.16;
				float streak = smoothstep(len, 0.0, yy);
				float fx = (fract(r.x / sc) - 0.5) * sc;
				float line = smoothstep(1.1, 0.2, abs(fx));
				rain_a += line * streak * (layer == 0 ? 0.32 : 0.2);
			}
		}
		add += vec3(0.72, 0.82, 0.95) * rain_a;
	}

	// ----------------------------------------------------------- lightning
	add += vec3(0.7, 0.78, 1.0) * flash * 0.75;

	// ------------------------------------------------------ transition mist
	if (fade > 0.001) {
		float cl2 = nz(wpos / 600.0 + vec2(t * 0.03, 0.0)).r;
		float fa2 = clamp(fade * 1.25 + (cl2 - 0.5) * 0.5 * fade, 0.0, 1.0);
		vec3 mist = vec3(0.05, 0.1, 0.16);
		add = add * (1.0 - fa2) + mist * fa2;
		a = a * (1.0 - fa2) + fa2;
	}

	COLOR = vec4(add, clamp(a, 0.0, 1.0));
}
