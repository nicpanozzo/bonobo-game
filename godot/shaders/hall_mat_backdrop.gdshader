// Fondale oltre le pareti e sopra il soffitto aperto: notte blu profonda che sfuma in viola, stelle che
// brillano, grandi cerchi di bokeh dorati e viola che passano piano e un velo d'aurora all'orizzonte.
// Va su HallMaterials.backdrop_mesh() (sfera grande vista da dentro).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, shadows_disabled, fog_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.01, 0.01, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.16, 0.06, 0.3);
uniform float stars = 1.0;
uniform float bokeh = 1.0;
uniform float aurora = 1.0;
uniform float motion = 1.0;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	float t = TIME * motion;
	vec3 d = normalize(dir);
	float y = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.05, 0.6, y));
	col = mix(col, top_color * 0.6, smoothstep(0.0, -0.4, y));
	col += HALL_GOLD * 0.06 * exp(-abs(y) * 12.0);
	vec2 sp = vec2(atan(d.z, d.x) / 6.2831853, asin(clamp(y, -1.0, 1.0)) / 3.14159);

	if (stars > 0.0) {
		vec2 q = sp * vec2(180.0, 90.0);
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5 - (hall_hash22(id) - 0.5) * 0.7;
		float h = hall_hash21(id + 2.1);
		float twinkle = 0.6 + 0.4 * sin(t * (1.0 + h * 3.0) + h * 40.0);
		float s = step(0.9, h) * smoothstep(0.12, 0.0, length(f)) * twinkle;
		col += mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.85, 0.5), step(0.97, h)) * s * stars * smoothstep(-0.05, 0.15, y);
	}
	if (bokeh > 0.0) {
		vec2 q = (sp + vec2(t * 0.002, 0.0)) * vec2(16.0, 8.0);
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5 - (hall_hash22(id + 5.0) - 0.5) * 0.5;
		float h = hall_hash21(id + 9.7);
		float rad = 0.12 + 0.18 * h;
		float dd = length(f * vec2(2.0, 1.0));
		float disc = smoothstep(rad, rad - 0.03, dd);
		float ring = smoothstep(0.025, 0.0, abs(dd - rad + 0.02));
		vec3 bc = mix(HALL_GOLD, HALL_PURPLE * 1.3, step(0.55, h));
		float show = step(0.62, hall_hash21(id + 3.3)) * smoothstep(-0.1, 0.25, y) * smoothstep(0.75, 0.35, y);
		col += bc * (disc * 0.08 + ring * 0.06) * show * bokeh;
	}
	if (aurora > 0.0) {
		float n = hall_fbm(vec2(sp.x * 9.0 + t * 0.02, sp.y * 3.0), 3.0);
		float band = exp(-pow((y - 0.18 - n * 0.12) * 9.0, 2.0));
		float curtain = 0.5 + 0.5 * sin(sp.x * 80.0 + n * 9.0 + t * 0.15);
		col += mix(HALL_PURPLE, vec3(0.3, 0.8, 0.9), n) * band * (0.08 + 0.1 * curtain) * aurora;
	}
	ALBEDO = col;
}
