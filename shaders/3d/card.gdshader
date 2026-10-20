shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
#include "res://shaders/3d/common.gdshaderinc"

uniform sampler2D card_tex : source_color, filter_linear_mipmap, repeat_disable;
varying vec2 v_w;
varying vec3 v_tint;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Sway the top of the sprite a little in the wind.
	float up = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * (1.1 + g_wind.x) + wp.x * 0.8 + wp.z * 0.5) * (0.02 + 0.07 * length(g_wind)) * up * up;
	v_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	v_tint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec4 c = texture(card_tex, UV);
	if (c.a < 0.45) {
		discard;
	}
	vec3 col = c.rgb * mix(vec3(1.0), v_tint * 1.6, 0.35);
	ALBEDO = fog_of_war(col, v_w, TIME);
	ROUGHNESS = 0.9;
	NORMAL = normalize(vec3(0.0, 0.0, 1.0));
}
