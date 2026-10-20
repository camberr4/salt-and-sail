shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/3d/common.gdshaderinc"

varying vec2 v_w;
varying vec3 v_tint;
varying float v_up;
varying vec3 v_col;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float up = clamp(VERTEX.y / 2.4, 0.0, 1.0);
	float sway = sin(TIME * (1.2 + g_wind.x) + wp.x * 0.9 + wp.z * 0.6) * (0.03 + 0.08 * length(g_wind)) * up * up;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	v_w = wp.xz;
	v_tint = INSTANCE_CUSTOM.rgb;
	v_col = COLOR.rgb;
	v_up = up;
}

void fragment() {
	float t = TIME;
	vec3 c = v_col * v_tint;
	// painterly leaf speckle
	vec2 wpx = v_w * CELL_PX;
	float sp = nz(wpx / 9.0 + vec2(v_up * 3.0)).a;
	c *= 0.8 + 0.4 * sp;
	c = mix(c, c * vec3(1.15, 1.2, 0.75), smoothstep(0.5, 1.0, v_up) * 0.5);
	ALBEDO = fog_of_war(c, v_w, t);
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	RIM = 0.25;
	RIM_TINT = 0.5;
}
