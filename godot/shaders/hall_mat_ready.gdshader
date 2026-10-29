// Cerchio "pronti": un anello di rune che gira piano, frecce che scendono verso il centro e una barra
// circolare che si riempie in senso orario da ore 12 con fill (0..1: quanti sono pronti sul totale).
// La parte piena è oro acceso, il resto viola spento; a fill = 1 tutto pulsa. Va su un PlaneMesh
// orizzontale (HallMaterials.ready_ring_mesh), con la telecamera dal lato +z.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.8, 0.22);
uniform vec3 idle_color : source_color = vec3(0.45, 0.25, 0.95);
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 1.7;
uniform float motion = 1.0;

float glyph(vec2 g, float seed) {
	// una runa: segmenti di una griglia 2x3 accesi a caso
	float s = 0.0;
	float w = 0.07;
	for (int i = 0; i < 3; i++) {
		float y = 0.15 + float(i) * 0.35;
		float on = step(0.45, hall_hash21(vec2(seed, float(i))));
		s += on * hall_line(abs(g.y - y), w) * step(0.2, g.x) * step(g.x, 0.8);
	}
	for (int j = 0; j < 2; j++) {
		float x = 0.2 + float(j) * 0.6;
		float on = step(0.4, hall_hash21(vec2(seed + 9.1, float(j))));
		s += on * hall_line(abs(g.x - x), w) * step(0.15, g.y) * step(g.y, 0.85);
	}
	float diag = step(0.7, hall_hash21(vec2(seed, 5.5)));
	s += diag * hall_line(abs(g.x - g.y), w) * step(0.15, g.y) * step(g.y, 0.85);
	return clamp(s, 0.0, 1.0);
}

void fragment() {
	float t = TIME * motion;
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c);
	float theta = atan(c.x, -c.y); // 0 a ore 12, cresce in senso orario visto dall'alto davanti
	float a01 = fract(theta / 6.2831853);
	float done = step(0.999, fill);
	float party = done * (0.5 + 0.5 * sin(t * 6.0));

	float filled = step(a01, fill);
	vec3 col_on = mix(color, vec3(1.0), 0.35);
	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// fondo scuro dell'anello
	float band = smoothstep(0.46, 0.48, r) * smoothstep(1.0, 0.98, r);
	col += vec3(0.02, 0.012, 0.04) * band;
	alpha += band * 0.75;

	// barra di avanzamento
	float bar = hall_line(abs(r - 0.8), 0.035);
	float bar_edge = hall_line(abs(r - 0.8), 0.045) - bar;
	float head = exp(-pow((a01 - fill) * 60.0, 2.0)) * step(0.001, fill) * (1.0 - done);
	vec3 bar_col = mix(idle_color * 0.35, col_on * (1.4 + party), filled);
	col += bar_col * bar * intensity + vec3(1.0) * head * bar * 2.0;
	col += idle_color * bar_edge * 0.6;
	alpha += bar;

	// rune che girano piano nella fascia esterna
	float n_cells = 40.0;
	float ra = fract(a01 + t * 0.008);
	float cell = floor(ra * n_cells);
	vec2 g = vec2(fract(ra * n_cells), (r - 0.865) / 0.09);
	float rune = glyph(g, cell) * step(0.0, g.y) * step(g.y, 1.0);
	float rune_on = step(fract(cell / n_cells - t * 0.008), fill);
	vec3 rune_col = mix(idle_color * 0.9, col_on * 1.2, rune_on);
	float flicker = 0.75 + 0.25 * sin(t * 3.0 + cell * 1.7);
	col += rune_col * rune * intensity * flicker;
	// filetti che chiudono la fascia
	float lines = hall_line(abs(r - 0.85), 0.006) + hall_line(abs(r - 0.97), 0.008) + hall_line(abs(r - 0.72), 0.006);
	col += mix(idle_color, color, 0.5 + 0.5 * done) * lines * intensity;
	alpha += lines + rune;

	// frecce che scendono verso il centro, 12 attorno
	float ca = fract(a01 * 12.0);
	float chev_v = fract(r * 7.0 + abs(ca - 0.5) * 1.6 + t * 0.6);
	float chev = hall_line(abs(chev_v - 0.5), 0.09) * step(0.5, r) * step(r, 0.7) * step(abs(ca - 0.5), 0.3);
	float chev_fade = smoothstep(0.5, 0.7, r);
	col += mix(idle_color, color, filled) * chev * chev_fade * intensity * (0.6 + party);
	alpha += chev * chev_fade;

	// bagliore al centro quando sono tutti pronti
	float core = exp(-r * r * 5.0) * (0.15 * fill + party * 0.6);
	col += color * core;
	alpha += core;

	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0) * smoothstep(1.0, 0.98, r);
}
