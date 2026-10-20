shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
varying float v_a;
void vertex() {
	v_a = COLOR.a;
}
void fragment() {
	float t = TIME;
	vec2 uv = UV;
	float edge = 1.0 - pow(abs(uv.x - 0.5) * 2.0, 1.6);
	float n1 = texture(noise_tex, vec2(uv.x * 0.9, uv.y * 0.35) + vec2(0.0, -t * 0.12)).a;
	float n2 = texture(noise_tex, vec2(uv.x * 2.1 + 0.3, uv.y * 0.8) + vec2(t * 0.02, -t * 0.2)).g;
	float foam = smoothstep(0.35, 0.8, n1 * 0.6 + n2 * 0.55) * edge;
	foam = max(foam, edge * edge * 0.45);
	ALBEDO = vec3(0.96, 0.99, 1.0);
	ALPHA = clamp(foam * v_a * 1.4, 0.0, 1.0);
}
