// Pareti della sala: pannelli esagonali in fibra di carbonio indaco con bordi smussati, fughe scure,
// qualche cella dal filo acceso che respira e una lama di luce che scorre piano lungo la parete.
// Proiezione nel mondo sull'asse dominante, come il pavimento: va su box, piani e colonne.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.075, 0.05, 0.17);
uniform vec3 accent : source_color = vec3(0.55, 0.3, 1.0); // filo delle celle accese
uniform vec3 accent_2 : source_color = vec3(1.0, 0.76, 0.25); // alcune celle in oro
uniform float hex_size = 0.55; // m, larghezza di una cella
uniform float lit_cells = 0.05; // quota di celle col filo acceso
uniform float sweep = 1.0; // forza della lama di luce che scorre
uniform float floor_y = 0.0; // m, quota del pavimento: la parete si scalda vicino a terra
uniform float motion = 1.0;
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME * motion;
	vec3 n_w = normalize(wnrm);
	vec3 an = abs(n_w);
	vec2 p;
	vec3 tan_u;
	if (an.y >= an.x && an.y >= an.z) {
		p = wpos.xz;
		tan_u = vec3(1.0, 0.0, 0.0);
	} else if (an.x >= an.z) {
		p = wpos.zy;
		tan_u = vec3(0.0, 0.0, 1.0);
	} else {
		p = wpos.xy;
		tan_u = vec3(1.0, 0.0, 0.0);
	}
	vec3 tan_v = normalize(cross(n_w, tan_u));
	if (dot(tan_v, vec3(0.0, 1.0, 0.0)) < 0.0 && an.y < 0.7) {
		tan_v = -tan_v;
	}

	// Celle esagonali (due griglie sfalsate, vince il centro più vicino)
	vec2 q = p / hex_size;
	const vec2 rr = vec2(1.0, 1.7320508);
	vec2 ga = mod(q, rr) - rr * 0.5;
	vec2 gb = mod(q - rr * 0.5, rr) - rr * 0.5;
	vec2 gv = dot(ga, ga) < dot(gb, gb) ? ga : gb;
	vec2 id = floor((q - gv) * 2.0 + 0.5);
	vec2 ap = abs(gv);
	float hd = max(dot(ap, normalize(rr)), ap.x);
	float e = 0.5 - hd; // 0 sul bordo, 0.5 al centro

	float rnd = hall_hash21(id);
	float rnd2 = hall_hash21(id + 7.3);
	float seam = 1.0 - smoothstep(0.012, 0.03, e);
	float bevel = (1.0 - smoothstep(0.03, 0.085, e)) * (1.0 - seam);

	// trama del carbonio: un diagonale fine che cambia col punto di vista
	float weave = 0.0;
	if (detail > 0.0) {
		vec2 wq = q * 22.0;
		float w1 = step(0.5, fract(wq.x * 0.5 + floor(wq.y) * 0.25));
		weave = mix(0.92, 1.08, w1) - 1.0;
		weave *= 1.0 - clamp(fwidth(wq.x) * 0.8, 0.0, 1.0);
	}

	vec3 col = base_color * (0.75 + 0.5 * rnd) * (1.0 + weave);
	// bordo smussato: la parte alta prende la luce, la bassa resta in ombra
	vec2 dir = normalize(gv + 1e-5);
	col += base_color * bevel * (1.6 * max(dir.y, 0.0) - 0.35);

	// filo acceso su alcune celle, ognuna col suo respiro
	float lit = step(1.0 - lit_cells, rnd2);
	float breathe = 0.55 + 0.45 * sin(t * (0.7 + rnd * 0.8) + rnd * 6.28);
	vec3 acc = mix(accent, accent_2, step(0.75, rnd));
	float rim = hall_line(abs(e - 0.07), 0.009) * lit;
	float inner = smoothstep(0.5, 0.0, e) * lit * 0.12;

	// lama di luce che scorre in orizzontale
	float sw_s = fract(dot(p, vec2(0.05, 0.012)) - t * 0.035);
	float sw = exp(-pow((sw_s - 0.5) * 14.0, 2.0)) * sweep;

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float F = hall_fresnel(n_w, V, 0.04);
	vec3 refl = hall_env(reflect(-V, n_w), t) * (F * 0.6 + 0.04);

	float warm = exp(-max(wpos.y - floor_y, 0.0) * 1.1);
	vec3 emis = acc * (rim * 1.3 + inner) * breathe;
	emis += vec3(0.9, 0.75, 1.0) * sw * (bevel * 0.35 + 0.03);
	emis += HALL_GOLD * warm * 0.06;
	emis += refl * (1.0 - seam);

	ALBEDO = mix(col, vec3(0.005), seam);
	ROUGHNESS = mix(0.35, 0.8, seam) - weave * 1.5;
	SPECULAR = 0.5;
	EMISSION = emis;
	// il bordo smussato inclina la normale: le luci vere ci disegnano i riflessi
	vec3 n_bev = normalize(n_w + (tan_u * dir.x + tan_v * dir.y) * bevel * 0.8);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_bev, 0.0)).xyz);
}
