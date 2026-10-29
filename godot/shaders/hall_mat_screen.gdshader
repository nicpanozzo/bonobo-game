// Maxischermo a LED (parete di fondo, tabellone della classifica): l'immagine campionata a griglia di
// led tondi, una banda di aggiornamento che scorre e la vignetta del vetro.
// Da lontano i led si fondono (fwidth) per non fare moiré. Senza immagine mostra un'attesa animata.
// Va su un QuadMesh/PlaneMesh con le UV intere (0..1); la cornice la fa hall_view col metallo.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform sampler2D screen_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float has_tex = 1.0;
uniform vec2 led_count = vec2(192.0, 108.0); // led in orizzontale e verticale
uniform float brightness = 1.7;
uniform float led_gap = 0.22; // 0..1 quanto buio tra un led e l'altro
uniform vec3 idle_a : source_color = vec3(0.42, 0.18, 0.95);
uniform vec3 idle_b : source_color = vec3(1.0, 0.8, 0.2);
uniform float motion = 1.0;

void fragment() {
	float t = TIME * motion;
	vec2 g = UV * led_count;
	vec2 cell = floor(g) + 0.5;
	vec2 suv = cell / led_count;
	vec3 img;
	if (has_tex > 0.5) {
		img = textureLod(screen_tex, suv, 0.0).rgb;
	} else {
		// attesa: un plasma lento viola/oro con un'onda di chevron
		float p = sin(suv.x * 6.0 + t * 0.6) + sin(suv.y * 5.0 - t * 0.4) + sin((suv.x + suv.y) * 4.0 + t * 0.3);
		img = mix(idle_a * 0.5, idle_b * 0.8, 0.5 + 0.25 * p);
		float chev = step(0.5, fract(suv.x * 8.0 - abs(suv.y - 0.5) * 3.0 - t * 0.4));
		img *= 0.7 + 0.3 * chev;
	}
	// led tondo con i tre sottopixel
	vec2 f = fract(g) - 0.5;
	float d = length(f);
	float dot_mask = 1.0 - smoothstep(0.5 - led_gap, 0.5 - led_gap * 0.4, d);
	// ogni led un filo diverso dagli altri, come nei pannelli veri
	float led_var = 0.9 + 0.2 * hall_hash21(cell);
	// il centro del led più caldo: sembra una lucina e non un pallino piatto
	float hot = 1.0 + 0.6 * (1.0 - smoothstep(0.0, 0.3, d));
	float far = clamp(max(fwidth(g.x), fwidth(g.y)) * 1.4 - 0.4, 0.0, 1.0);
	vec3 led = img * mix(dot_mask * hot * led_var * 1.3, vec3(0.9), far);
	// banda di aggiornamento e righe orizzontali appena visibili
	float roll = exp(-pow((fract(UV.y * 0.6 - t * 0.12) - 0.5) * 9.0, 2.0)) * 0.12;
	float vign = 1.0 - 0.35 * pow(length(UV - 0.5) * 1.35, 2.5);
	vec3 col = led * brightness * vign * (1.0 + roll);
	// riflesso del vetro: una diagonale chiara fissa
	float glare = smoothstep(0.02, 0.0, abs(UV.x + UV.y * 0.6 - 0.35)) * 0.05 + smoothstep(0.12, 0.0, abs(UV.x + UV.y * 0.6 - 0.45)) * 0.03;
	ALBEDO = col + vec3(glare) + vec3(0.008, 0.006, 0.015);
}
