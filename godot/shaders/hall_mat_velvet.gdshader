// Velluto per stendardi, tende e cuscino del trono: colore pieno che si schiarisce di taglio (lucentezza
// del pelo), pieghe verticali che ondeggiano piano, bordo e frange d'oro, a scelta lo stemma della banana
// al centro, il fondo a coda di rondine e la capitonnè a bottoni. Le UV del quad: v = 0 in alto.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(0.35, 0.08, 0.55);
uniform vec3 trim_color : source_color = vec3(1.0, 0.74, 0.3);
uniform float folds = 1.0; // forza delle pieghe verticali
uniform float fold_count = 6.0;
uniform float sway = 1.0; // pieghe che ondeggiano (stendardi appesi)
uniform float trim = 1.0; // bordo d'oro sui lati e in basso
uniform float crest = 0.0; // 1 = stemma della banana al centro
uniform float swallowtail = 0.0; // 1 = fondo a punta (stendardo), 0 = dritto
uniform float tufted = 0.0; // 1 = capitonnè a bottoni (cuscino del trono)
uniform float aspect = 2.6; // altezza / larghezza del quad: lo stemma resta tondo
uniform float motion = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// ondeggia di più in basso, dove lo stendardo è libero
	float s = sin(UV.x * fold_count * 3.14159 + TIME * motion * 1.1) * 0.03 * sway * UV.y;
	VERTEX += NORMAL * s;
}

// stemma: una banana (arco che si assottiglia alle punte, col picciolo a destra) dentro un rombo.
// tip = punte scure, shade = -1 sul lato interno, +1 su quello esterno della curva
float crest_mask(vec2 p, out float edge, out float tip, out float shade) {
	vec2 d = p - vec2(0.0, 0.24);
	float a = atan(d.x, -d.y);
	float rad = length(d);
	float span = 1.2;
	float k = clamp(abs(a) / span, 0.0, 1.0);
	float th = 0.07 * (1.0 - k * k) + 0.008;
	float body = abs(a) > span ? 1.0 : abs(rad - 0.3) - th;
	float stem = (a > span - 0.05 && a < span + 0.24) ? abs(rad - 0.3) - 0.02 : 1.0;
	tip = max(smoothstep(0.86, 0.97, k), step(span, a));
	shade = clamp((rad - 0.3) / th, -1.0, 1.0);
	vec2 q = abs(p);
	edge = abs((q.x + q.y) - 0.38) - 0.008;
	return min(body, stem);
}

void fragment() {
	float t = TIME * motion;
	vec2 uv = UV;
	// coda di rondine: taglio a V in basso
	if (swallowtail > 0.5) {
		float cut = 0.86 + abs(uv.x - 0.5) * 0.28;
		if (uv.y > cut) {
			discard;
		}
	}
	float fold = sin(uv.x * fold_count * 6.2831853 + sin(uv.y * 3.0 + t * 0.7) * 0.6 * sway);
	float fold_shade = 1.0 + fold * 0.22 * folds;
	vec3 col = color * fold_shade;
	float rough_n = hall_noise(uv * vec2(120.0, 300.0));
	col *= 0.92 + 0.16 * rough_n;
	float tuft_shade = 1.0;
	if (tufted > 0.5) {
		vec2 tq = uv * vec2(5.0, 4.0);
		vec2 rot = vec2(tq.x + tq.y, tq.x - tq.y) * 0.7071;
		vec2 tf = abs(fract(rot) - 0.5);
		float d = length(fract(rot) - 0.5);
		tuft_shade = 0.6 + 0.6 * smoothstep(0.0, 0.5, min(tf.x, tf.y) * 2.0);
		float button = 1.0 - smoothstep(0.05, 0.08, d);
		col = mix(col * tuft_shade, trim_color * 0.8, button);
	}
	// lucentezza del velluto: di taglio il pelo prende luce
	float facing = abs(dot(NORMAL, VIEW));
	float sheen = pow(1.0 - facing, 2.5);
	vec3 emis = mix(color, vec3(1.0, 0.9, 1.0), 0.35) * sheen * 0.45 * fold_shade;
	// bordo d'oro
	float tr = 0.0;
	if (trim > 0.0) {
		float bottom = swallowtail > 0.5 ? (0.86 + abs(uv.x - 0.5) * 0.28) - uv.y : 1.0 - uv.y;
		float d = min(min(uv.x, 1.0 - uv.x), bottom);
		tr = hall_line(abs(d - 0.045), 0.012) + (1.0 - smoothstep(0.012, 0.016, d));
		tr = clamp(tr, 0.0, 1.0) * trim;
	}
	float cr = 0.0;
	float cr_edge = 0.0;
	float cr_tip = 0.0;
	float cr_shade = 0.0;
	if (crest > 0.5) {
		vec2 p = (uv - vec2(0.5, 0.36)) * vec2(1.0, aspect) * 1.1;
		p.y = -p.y;
		float e;
		float b = crest_mask(p, e, cr_tip, cr_shade);
		cr = 1.0 - smoothstep(-0.004, 0.004, b);
		cr_edge = 1.0 - smoothstep(0.0, 0.006, e);
	}
	float gold = clamp(tr + cr_edge, 0.0, 1.0);
	float shine = 0.6 + 0.6 * pow(1.0 - facing, 1.5) + 0.2 * sin(t * 0.8 + uv.y * 4.0);
	vec3 banana = vec3(1.0, 0.85, 0.2);
	col = mix(col, trim_color * 0.5, gold);
	// banana: più chiara sul dorso, più calda all'interno, punte e picciolo marroni
	vec3 banana_col = banana * (0.85 + 0.3 * cr_shade) + vec3(0.0, -0.08, -0.05) * max(-cr_shade, 0.0);
	banana_col = mix(banana_col, vec3(0.3, 0.18, 0.04), cr_tip);
	float outline = cr * smoothstep(0.75, 1.0, abs(cr_shade)) * (1.0 - cr_tip);
	banana_col *= 1.0 - outline * 0.5;
	col = mix(col, banana_col * 0.7, cr);
	emis += trim_color * gold * 0.55 * shine + banana_col * cr * (0.35 + 0.35 * shine);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = emis;
}
