// Pavimento della sala (e marmo dei piedistalli): marmo scuro lucidato con venature e scaglie di
// terrazzo, intarsi d'oro che si illuminano a onde dal centro, un rosone a stella e il riflesso finto
// della sala (hall_env) che sale guardando di sbieco. Proiezione nel mondo: niente UV da sistemare.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 base_a : source_color = vec3(0.04, 0.032, 0.075);
uniform vec3 base_b : source_color = vec3(0.075, 0.045, 0.115);
uniform vec3 vein_color : source_color = vec3(0.72, 0.62, 0.95);
uniform vec3 inlay_color : source_color = vec3(1.0, 0.76, 0.25);
uniform float tile_size = 2.0; // m, lato di una lastra
uniform float inlay = 1.0; // 0 = solo marmo, senza intarsi (piedistalli, pedana)
uniform float inlay_width = 0.014; // m, mezza larghezza della riga d'oro
uniform float inlay_glow = 0.45; // quanto brillano gli intarsi (l'onda e la lama li accendono di più)
uniform float polish = 1.0; // forza del riflesso finto
uniform float vein_scale = 0.4; // venature per metro
uniform float vein_strength = 1.0;
uniform vec2 medallion_center = vec2(0.0, 0.0); // m, sul piano xz
uniform float medallion_radius = 0.0; // m, 0 = niente rosone
uniform float motion = 1.0; // 0 = fermo (meno movimento, Access.calm)
uniform float detail = 1.0; // 0 = versione leggera per telefoni lenti

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Proiezione sull'asse dominante: il marmo segue il mondo su pavimento, gradini e lati dei piedistalli
vec2 planar(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) {
		return p.xz;
	}
	if (a.x >= a.z) {
		return p.zy;
	}
	return p.xy;
}

void fragment() {
	float t = TIME * motion;
	vec3 n_w = normalize(wnrm);
	vec2 q = planar(wpos, n_w);
	vec2 cell = floor(q / tile_size);
	float tile_rand = hall_hash21(cell);
	float checker = mod(cell.x + cell.y, 2.0);

	// Marmo: venature fini su un fondo mosso, ogni lastra tagliata in un punto diverso del blocco
	vec2 mq = q * vein_scale + tile_rand * 13.0;
	float n = hall_fbm(mq * 1.3, 2.0 + detail);
	float warp = hall_fbm(mq * 0.6 + 3.1, 2.0);
	float v = abs(sin((mq.x + mq.y * 0.55) * 2.6 + n * 5.0 + warp * 4.5));
	float vein_aa = clamp(fwidth(v) * 2.0, 0.0, 1.0);
	float veins = pow(1.0 - v, mix(26.0, 6.0, vein_aa)) * (1.0 - vein_aa * 0.6);
	float veins_soft = pow(1.0 - v, 3.0);
	// seconda rete di vene più sottili, di traverso
	float v2 = abs(sin((mq.y - mq.x * 0.35) * 4.1 + warp * 7.0 + n * 3.0));
	float veins2 = pow(1.0 - v2, mix(40.0, 10.0, vein_aa)) * smoothstep(0.35, 0.6, n) * detail;
	vec3 base = mix(base_a, base_b, clamp(checker * 0.6 + (n - 0.5) * 1.1, 0.0, 1.0));
	base += vein_color * (veins * 0.4 + veins2 * 0.22 + veins_soft * 0.04) * vein_strength;
	// macchie più chiare come nel marmo vero
	base += vein_color * 0.06 * smoothstep(0.55, 0.85, warp) * vein_strength;

	// Terrazzo: scaglie d'oro e madreperla, sparite da lontano per non sfarfallare
	vec2 fq = q / 0.07;
	vec2 fi = floor(fq);
	vec2 ff = fract(fq) - 0.5;
	vec2 fo = (hall_hash22(fi) - 0.5) * 0.55;
	float fr = hall_hash21(fi + 3.7);
	float fd = length(ff - fo);
	float far_fade = 1.0 - smoothstep(0.25, 0.6, fwidth(fq.x) + fwidth(fq.y));
	float fleck = (1.0 - smoothstep(0.06, 0.13, fd)) * step(0.86, fr) * far_fade * detail;
	vec3 fleck_col = mix(vec3(1.0, 0.78, 0.38), vec3(0.85, 0.82, 1.0), step(0.95, fr));
	base = mix(base, fleck_col * 0.55, fleck * 0.8);

	// Intarsi: una riga d'oro a ogni lastra, una doppia ogni quattro, rombi agli incroci
	vec2 gd = abs(fract(q / tile_size + 0.5) - 0.5) * tile_size;
	float dl = min(gd.x, gd.y);
	float grid = hall_line(dl, inlay_width);
	vec2 gd4 = abs(fract(q / (tile_size * 4.0) + 0.5) - 0.5) * tile_size * 4.0;
	float d4 = min(gd4.x, gd4.y);
	float major = hall_line(abs(d4 - inlay_width * 5.0), inlay_width * 0.7);
	float diamond_d = gd.x + gd.y;
	float diamond = hall_line(abs(diamond_d - inlay_width * 7.0), inlay_width * 0.8) + hall_line(diamond_d, inlay_width * 2.5);
	float gold = clamp(grid + major + diamond, 0.0, 1.0);
	// canalina scura ai lati della riga d'oro: dà profondità all'intarsio
	float groove = hall_line(dl, inlay_width * 2.6) * (1.0 - grid) * inlay;

	// Rosone a otto punte al centro della sala: dentro sostituisce la griglia
	float r = length(wpos.xz - medallion_center);
	float star_fill = 0.0;
	float star_shade = 0.0;
	if (medallion_radius > 0.0) {
		float R = medallion_radius;
		vec2 mc = wpos.xz - medallion_center;
		float a = atan(mc.y, mc.x);
		gold *= smoothstep(R * 1.0, R * 1.04, r);
		groove *= smoothstep(R * 1.0, R * 1.04, r);
		float rings = hall_line(abs(r - R), inlay_width * 1.6) + hall_line(abs(r - R * 0.94), inlay_width * 0.7)
			+ hall_line(abs(r - R * 0.38), inlay_width) + hall_line(abs(r - R * 0.12), inlay_width * 0.8);
		// tacche tra i due anelli esterni
		float tick_a = abs(fract(a / 6.2831853 * 72.0 + 0.5) - 0.5) * 6.2831853 / 72.0 * r;
		float ticks = hall_line(tick_a, inlay_width * 0.5) * step(R * 0.94, r) * step(r, R);
		// stella: punte lunghe sugli assi, corte in diagonale
		float k8 = abs(cos(a * 4.0));
		float k4 = abs(cos(a * 2.0));
		float star_r = R * mix(0.2, mix(0.62, 0.9, step(0.5, k4 * k4)), pow(k8, 10.0));
		star_fill = (1.0 - smoothstep(star_r - 0.02, star_r + 0.02, r)) * step(R * 0.12, r);
		star_shade = step(0.0, sin(a * 8.0));
		float star_edge = hall_line(abs(r - star_r), inlay_width * 0.9) * step(R * 0.12, r);
		// raggi della stella: il filo al centro di ogni punta
		float ray_d = abs(sin(a * 4.0)) * r;
		float rays = hall_line(ray_d, inlay_width * 0.5) * step(r, star_r) * step(R * 0.12, r);
		gold = clamp(gold + rings + ticks + star_edge + rays, 0.0, 1.0);
	}

	// Onda di luce che parte dal centro e attraversa gli intarsi, più una lama lenta in diagonale
	float wave = pow(0.5 + 0.5 * sin(t * 1.2 - r * 0.35), 6.0);
	float sweep_s = fract((q.x * 0.7 + q.y) / 36.0 - t * 0.045);
	float sweep = exp(-pow((sweep_s - 0.5) * 22.0, 2.0));

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 R_dir = reflect(-V, n_w);
	// marmo lucido ma non uno specchio: il riflesso ondeggia un filo con la venatura
	R_dir.xz += (n - 0.5) * 0.05;
	float F = hall_fresnel(n_w, V, 0.05);
	vec3 env_c = hall_env(normalize(R_dir), t);
	vec3 refl = env_c * (F * 1.3 + 0.03) * polish;

	vec3 star_col = mix(inlay_color * 0.32, inlay_color * 0.1, star_shade) * star_fill;
	vec3 albedo = (base + star_col) * (1.0 - groove * 0.7);
	ALBEDO = mix(albedo, inlay_color * 0.6, gold);
	METALLIC = gold * 0.85;
	ROUGHNESS = mix(mix(0.12, 0.28, n), 0.25, gold);
	SPECULAR = 0.65;
	// l'oro riflette la sala come metallo, più l'onda e la lama che passano
	float gold_lum = 0.4 + 0.6 * dot(env_c, vec3(0.5));
	vec3 glow = inlay_color * gold * inlay * (inlay_glow * gold_lum + wave * 0.9 + sweep * 1.6);
	glow += inlay_color * star_fill * (0.03 + 0.05 * star_shade) * (0.6 + wave) * inlay;
	EMISSION = refl * (1.0 - gold) * (1.0 - groove * 0.8) + glow + vec3(1.0, 0.9, 0.7) * sweep * 0.02 * polish;
}
