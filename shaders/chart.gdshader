shader_type canvas_item;

// Hand-inked sea chart. Used for the round minimap and the full-screen chart.
// Only explored waters are drawn; the rest stays blank parchment.

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D explored_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 world_size = vec2(10800.0, 19200.0);
uniform vec2 view_center = vec2(5400.0, 9600.0);
uniform vec2 view_size = vec2(10800.0, 19200.0);
uniform float circle_mask = 0.0;
uniform float reveal_all = 0.0;
uniform vec2 grid_step = vec2(1080.0, 1920.0);
uniform float dim = 0.0;

vec4 nz(vec2 p) {
	return texture(noise_tex, p);
}

void fragment() {
	vec2 world = view_center + (UV - 0.5) * view_size;
	vec2 uv = world / world_size;
	vec4 paper_n = nz(world / 700.0);
	vec4 fine_n = nz(world / 90.0);
	vec3 paper = mix(vec3(0.93, 0.85, 0.66), vec3(0.86, 0.76, 0.55), paper_n.r * 0.7 + fine_n.a * 0.2);
	paper *= 0.96 + 0.06 * fine_n.g;

	vec3 col = paper;
	bool inside = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	if (inside) {
		vec4 hs = texture(height_tex, uv);
		float h = hs.r + (nz(world / 160.0).g - 0.5) * 0.012;
		float ex = max(texture(explored_tex, uv).r, reveal_all);
		float px = view_size.x / 1000.0; // world units per rough screen px
		float fw = max(fwidth(h) * 1.4, 0.0005);

		vec3 sea_c = vec3(0.70, 0.82, 0.80);
		vec3 land_c = mix(vec3(0.88, 0.80, 0.55), vec3(0.62, 0.70, 0.42), clamp(hs.g * 1.2, 0.0, 1.0));
		land_c = mix(land_c, vec3(0.66, 0.62, 0.56), smoothstep(0.7, 1.0, hs.b) * 0.8);
		float rock = smoothstep(0.26, 0.4, h - 0.5);
		land_c = mix(land_c, vec3(0.72, 0.7, 0.66), rock * 0.6);
		vec3 base = h > 0.5 ? land_c : mix(sea_c, vec3(0.55, 0.72, 0.76), smoothstep(0.5, 0.3, h) * 0.6);
		base *= 0.94 + 0.1 * fine_n.g;

		// Hatching in the shallows, like engraved water lines.
		float shallow = smoothstep(0.5, 0.42, h) * step(h, 0.5);
		float lines = smoothstep(0.35, 0.5, abs(fract((world.x + world.y * 0.6) / (view_size.x * 0.012 + 26.0)) - 0.5));
		base = mix(base, base * vec3(0.78, 0.9, 0.92), lines * shallow * 0.55);
		// Ink coastline, plus a lighter echo line in the water.
		float coast = 1.0 - smoothstep(0.0, fw * 1.6, abs(h - 0.5));
		float echo = 1.0 - smoothstep(0.0, fw * 1.4, abs(h - 0.455));
		base = mix(base, vec3(0.30, 0.20, 0.12), coast * 0.9);
		base = mix(base, vec3(0.36, 0.28, 0.2), echo * 0.32);

		float k = smoothstep(0.25, 0.75, ex + (paper_n.g - 0.5) * 0.25);
		col = mix(paper * vec3(0.97, 0.94, 0.9), base, k);
	}
	// Faint grid.
	vec2 g = abs(fract(world / grid_step + 0.5) - 0.5) * grid_step;
	float gl = 1.0 - smoothstep(0.0, view_size.x * 0.0016 + 1.0, min(g.x, g.y));
	col = mix(col, vec3(0.45, 0.32, 0.2), gl * 0.2);

	// Aged edges.
	vec2 e = (UV - 0.5) * 2.0;
	float vig = smoothstep(0.7, 1.35, max(abs(e.x), abs(e.y)));
	col *= 1.0 - vig * 0.22;
	col *= 1.0 - dim;

	float a = 1.0;
	if (circle_mask > 0.5) {
		a = 1.0 - smoothstep(0.96, 1.0, length(e));
	}
	COLOR = vec4(col, a);
}
