// Pedana di una modalità: disco di vetro scuro con anelli d'energia nel colore della modalità. A riposo
// respira piano; con active verso 1 (hall_view lo anima quando qualcuno ci sale) gli anelli corrono verso
// fuori, l'anello a tratti gira più veloce e il centro si accende. Va su HallMaterials.pad_mesh():
// il disco occupa l'80% del quadrato, il resto è l'alone.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.84, 0.18);
uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform float intensity = 1.6;
uniform float motion = 1.0;
uniform float phase = 0.0;

const float DISC = 0.8; // raggio del disco nel quadrato (0..1), fuori c'è l'alone

void fragment() {
	float t = TIME * motion + phase;
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c) / DISC; // 1 = bordo del disco
	float a = atan(c.y, c.x);
	float act = active;
	float aa = fwidth(r) * 1.5;

	// vetro scuro con una trama esagonale appena visibile
	vec2 hq = c * 9.0;
	vec2 hr = vec2(1.0, 1.7320508);
	vec2 h1 = mod(hq, hr) - hr * 0.5;
	vec2 h2 = mod(hq - hr * 0.5, hr) - hr * 0.5;
	vec2 hg = dot(h1, h1) < dot(h2, h2) ? h1 : h2;
	vec2 hp = abs(hg);
	float hex_edge = 0.5 - max(dot(hp, normalize(hr)), hp.x);
	float hex = hall_line(hex_edge, 0.035) * 0.35;
	// vetro scuro che verso il bordo prende il colore, come illuminato da dentro
	vec3 glass = mix(vec3(0.012, 0.008, 0.03), color * 0.14, (0.2 + 0.35 * act) * (0.4 + 0.6 * smoothstep(0.2, 0.95, r)));

	vec3 hot = mix(color, vec3(1.0), 0.25 + 0.3 * active);
	float rim = hall_line(abs(r - 0.96), 0.025);
	float rim2 = hall_line(abs(r - 0.865), 0.008);
	// anello a tratti che gira, più veloce quando la pedana è attiva
	float seg_a = fract((a / 6.2831853) * 24.0 + t * (0.05 + 0.25 * act));
	float dashes = hall_line(abs(r - 0.78), 0.022) * step(0.35, seg_a);
	// tacche sottili tra i due anelli esterni
	float ticks = step(0.86, r) * step(r, 0.93) * hall_line(abs(fract(a / 6.2831853 * 72.0) - 0.5) - 0.42, 0.06);
	// onde che partono dal centro
	float wave_r = fract(r * 2.0 - t * (0.25 + 0.9 * act));
	float waves = smoothstep(0.0, 0.08, wave_r) * smoothstep(0.35, 0.08, wave_r) * step(r, 0.74);
	waves *= 0.12 + 0.55 * act;
	// quattro archi interni che girano al contrario
	float arc_a = fract((a / 6.2831853) * 4.0 - t * (0.03 + 0.12 * act));
	float arcs = hall_line(abs(r - 0.6), 0.012) * smoothstep(0.0, 0.05, arc_a) * smoothstep(0.55, 0.45, arc_a);
	float core = exp(-r * r * 6.0) * (0.15 + 0.6 * act);
	float breath = 0.85 + 0.15 * sin(t * 2.0);

	float inside = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
	vec3 col = glass + color * hex * (0.4 + act * 0.6) * inside;
	float light = rim * 1.0 + rim2 * 0.6 + dashes * 0.9 + ticks * 0.5 + arcs * 0.7;
	col += hot * light * intensity * breath * (0.75 + 0.5 * act);
	col += color * (waves + core) * intensity;
	// alone fuori dal disco: il bagliore che si posa sul pavimento
	float halo = exp(-max(r - 1.0, 0.0) * (7.0 - 2.0 * act)) * step(1.0, r) * (0.35 + 0.45 * act);
	float edge_fade = smoothstep(1.25, 1.1, r);
	ALBEDO = col + color * halo * intensity * breath;
	ALPHA = clamp(max(inside * 0.92, halo * 1.2) * edge_fade + light * 0.0, 0.0, 1.0);
}
