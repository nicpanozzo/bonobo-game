// Retina del canestro: corda bianca intrecciata a rombi, il resto è vuoto (scarto, così la profondità resta
// giusta). Va su HallMaterials.hoop_net() (cilindro aperto che si stringe in basso, UV.y = 0 in alto).
// swish (0..1, hall_view lo fa scendere a 0) la fa sobbalzare quando entra un canestro.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 rope : source_color = vec3(0.96, 0.95, 0.92);
uniform float around = 12.0; // rombi lungo la circonferenza
uniform float down = 5.0; // rombi in altezza
uniform float thickness = 0.07; // spessore della corda, in quota del rombo
uniform float swish = 0.0;
uniform float motion = 1.0;

void vertex() {
	// sobbalzo: la retina si allunga e si stringe al centro, più in basso che in alto
	float k = swish * UV.y;
	VERTEX.y -= k * 0.25 * (0.6 + 0.4 * sin(TIME * motion * 30.0));
	VERTEX.xz *= 1.0 - k * 0.2;
}

void fragment() {
	vec2 g = vec2(UV.x * around, UV.y * down);
	float d1 = abs(fract(g.x + g.y) - 0.5);
	float d2 = abs(fract(g.x - g.y) - 0.5);
	float cord = max(hall_line(0.5 - d1, thickness), hall_line(0.5 - d2, thickness));
	// nodi più grossi dove le corde si incrociano
	float knot = (1.0 - smoothstep(0.0, thickness * 1.6, max(0.5 - d1, 0.5 - d2)));
	float a = max(cord, knot);
	if (a < 0.5) {
		discard;
	}
	// in alto la corda è più nuova e chiara, in basso un filo più grigia
	ALBEDO = rope * (1.0 - UV.y * 0.15);
	ROUGHNESS = 0.9;
	EMISSION = rope * 0.12;
}
