// Shared by terrain, trees, rocks and water: world constants and the fog of war.
const float CELL_PX = 24.0;
const vec2 GRID = vec2(450.0, 800.0);
const float HS = 30.0;

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
global uniform vec4 g_ship; // xy = world px, z = vision radius px

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D explored_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float reveal_all = 0.0;

vec4 nz(vec2 p) {
	return texture(noise_tex, p);
}

float luma3(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Fog of war: returns the colour mixed towards moving murk where unexplored.
// `w` is the world position in cells (x, z).
vec3 fog_of_war(vec3 col, vec2 w, float t) {
	vec2 wpx = w * CELL_PX;
	vec2 uv = w / GRID;
	vec2 wd = normalize(g_wind + vec2(0.0001, 0.0));
	float dist = length(wpx - g_ship.xy);
	float vr = g_ship.z;
	vec4 n_mid = nz(wpx / 330.0);
	float wob = (n_mid.g - 0.5) * 0.28 * vr;
	float visible = 1.0 - smoothstep(vr * 0.58, vr * 1.0 + wob, dist);
	float ex = max(texture(explored_tex, uv).r, reveal_all);
	float fogc = nz(wpx / 760.0 + wd * t * 0.007).r * 0.6 + nz(wpx / 310.0 - wd * t * 0.011 + 0.2).g * 0.4;
	vec2 world_px = GRID * CELL_PX;
	float edge_d = min(min(wpx.x, wpx.y), min(world_px.x - wpx.x, world_px.y - wpx.y));
	float rev = max(ex, visible) * smoothstep(140.0, 520.0, edge_d + (fogc - 0.5) * 240.0);
	rev = smoothstep(0.2, 0.8, rev + (fogc - 0.5) * 0.3);
	vec3 remembered = mix(col, vec3(luma3(col)) * vec3(0.78, 0.9, 1.05), 0.38) * 0.8;
	vec3 shown = mix(remembered, col, visible);
	vec3 murk = mix(vec3(0.05, 0.12, 0.19), vec3(0.2, 0.31, 0.4), fogc);
	return mix(murk, shown, rev);
}
