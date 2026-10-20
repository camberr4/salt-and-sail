shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/3d/common.gdshaderinc"

uniform float billow = 0.5;     // signed: which side the sail belly points to
uniform float flutter = 0.1;
uniform vec3 cloth = vec3(0.95, 0.9, 0.78);
varying vec2 v_w;
varying float v_belly;

void vertex() {
	// UV.x runs along the boom/foot (0 = at the mast), UV.y from foot (0) to head (1).
	float belly = sin(PI * clamp(UV.x, 0.0, 1.0)) * sin(PI * clamp(UV.y * 0.9 + 0.05, 0.0, 1.0));
	float fl = sin(TIME * 7.0 + UV.x * 9.0 + UV.y * 5.0) * flutter * UV.x * (0.4 + UV.y);
	VERTEX.z += (belly * billow) + fl;
	v_belly = belly;
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 wpx = v_w * CELL_PX;
	float weave = nz(UV * vec2(40.0, 60.0)).a;
	float seam = smoothstep(0.46, 0.5, abs(fract(UV.y * 7.0) - 0.5));
	vec3 c = cloth * (0.86 + 0.18 * weave);
	c *= 1.0 - 0.16 * seam;
	c *= 1.0 - 0.22 * v_belly * step(0.0, billow) ;
	c = mix(c, c * vec3(0.78, 0.72, 0.62), smoothstep(0.0, 1.0, UV.x) * 0.25);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
	BACKLIGHT = vec3(0.35, 0.3, 0.2);
}
