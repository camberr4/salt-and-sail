shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;
#include "res://shaders/3d/common.gdshaderinc"

uniform sampler2D decal_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_mul = 1.0;
varying vec2 v_w;
varying vec2 v_pix;

void vertex() {
	v_w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
}

void fragment() {
	vec4 c = texture(decal_tex, UV);
	ALPHA = c.a * alpha_mul;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
	// Discovered places stay visible; they just dim when out of sight.
	float vis = fog_state(v_w, TIME).y;
	ALBEDO = mix(c.rgb * 0.78, c.rgb, vis);
	ROUGHNESS = 0.9;
	NORMAL = vec3(0.0, 0.0, 1.0);
}
