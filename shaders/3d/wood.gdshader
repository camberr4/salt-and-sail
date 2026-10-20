shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/3d/common.gdshaderinc"

varying vec3 v_col;
varying vec3 v_local;

void vertex() {
	v_col = COLOR.rgb;
	v_local = VERTEX;
}

void fragment() {
	float grain = nz(vec2(v_local.x * 0.9, v_local.y * 5.5 + v_local.z * 0.3)).a;
	float plank = smoothstep(0.45, 0.5, abs(fract(v_local.y * 3.2) - 0.5));
	vec3 c = v_col * (0.8 + 0.35 * grain);
	c *= 1.0 - 0.3 * plank;
	ALBEDO = c;
	ROUGHNESS = 0.78;
	SPECULAR = 0.2;
}
