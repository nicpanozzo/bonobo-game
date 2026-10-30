// Pezzi degli scacchi giganti: marmo avorio caldo (bianchi) o ossidiana nera lucida con riflessi viola
// (neri), tutti e due con vene d'oro sottili. Le vene sono nello spazio dell'oggetto, così restano
// attaccate al pezzo quando si muove. gold_below: sotto questa quota locale (m) il pezzo è d'oro
// (il basamento); -1 = niente fascia.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform float black = 0.0; // 0 = avorio, 1 = ossidiana
uniform vec3 ivory : source_color = vec3(0.96, 0.88, 0.74);
uniform vec3 obsidian : source_color = vec3(0.035, 0.025, 0.05);
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.28);
uniform float vein_scale = 2.5; // vene per metro
uniform float gold_below = -1.0; // m, quota locale sotto cui il pezzo è d'oro
uniform float highlight = 0.0; // 0..1 pezzo selezionato: un bordo di luce dorata
uniform float motion = 1.0;
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	float t = TIME * motion;
	// proiezione sull'asse dominante della normale locale
	vec3 an = abs(lnrm);
	vec2 q = an.y > max(an.x, an.z) ? lpos.xz : (an.x > an.z ? lpos.zy : lpos.xy);
	q *= vein_scale;
	float n = hall_fbm(q * 1.3 + black * 5.0, 2.0 + detail);
	vec2 vq = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q * vec2(0.6, 1.4);
	float v = abs(hall_fbm(vq + n * 1.6, 2.0 + detail) - 0.5) * 2.0;
	float aa = clamp(fwidth(v) * 3.0, 0.0, 1.0);
	float veins = pow(1.0 - v, mix(30.0, 9.0, aa)) * (1.0 - aa * 0.6);
	float soft = pow(1.0 - v, 4.0);

	vec3 n_w = normalize(wnrm);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 R = reflect(-V, n_w);
	vec3 env = hall_env(normalize(R), t);
	float F = hall_fresnel(n_w, V, mix(0.04, 0.06, black));
	float rim = pow(1.0 - clamp(dot(n_w, V), 0.0, 1.0), 3.0);

	vec3 col;
	vec3 emis;
	if (black > 0.5) {
		// ossidiana: quasi nera, il colore lo fanno i riflessi e un velo viola di taglio
		col = obsidian * (0.8 + 0.5 * n);
		emis = env * (F * 1.8 + 0.08) + HALL_PURPLE * rim * 0.35;
	} else {
		// avorio: caldo, con le vene grigie morbide e un po' di luce che "passa" (finta traslucenza)
		col = ivory * (0.9 + 0.15 * n) - vec3(0.2, 0.18, 0.12) * soft * 0.25;
		// luce calda propria: sotto le luci viola della sala l'avorio resta avorio e non diventa lilla
		emis = env * (F * 1.0 + 0.02) + ivory * (0.13 + rim * 0.12);
	}
	float g = veins * (0.6 + 0.4 * black);
	float band = gold_below > 0.0 ? 1.0 - step(gold_below, lpos.y) : 0.0;
	g = max(g, band);
	float gold_l = 0.4 + 0.6 * dot(env, vec3(0.5));
	emis += gold * g * gold_l * 0.8 + gold * rim * highlight * (1.2 + 0.4 * sin(t * 5.0));

	ALBEDO = mix(col, gold * 0.6, g);
	METALLIC = g * 0.9;
	ROUGHNESS = mix(mix(0.22, 0.06, black), 0.25, g);
	SPECULAR = 0.65;
	EMISSION = emis;
}
