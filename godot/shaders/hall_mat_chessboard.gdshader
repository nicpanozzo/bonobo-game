// Scacchiera gigante: 8 x 8 caselle di marmo (avorio venato e ossidiana viola venata d'oro) divise da fili
// d'oro, dentro una cornice d'ossidiana col bordo dorato. Lucidata: riflette la sala come il pavimento.
// select_square accende una casella (la mossa scelta). Con squares = 1 fa una casella sola
// (chess_square_material). Va su un PlaneMesh quadrato: colonna a con u = 0, traversa 1 con v = 1.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform float squares = 8.0;
uniform float border = 0.06; // quota del lato occupata dalla cornice (0 = niente cornice)
uniform float board_size = 8.0; // m, lato del PlaneMesh: le vene restano della misura giusta
uniform float first_light = 0.0; // 1 = la casella (0, 0) è chiara (a1 è scura negli scacchi)
uniform vec3 light_color : source_color = vec3(0.9, 0.86, 0.78);
uniform vec3 dark_color : source_color = vec3(0.07, 0.035, 0.11);
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.28);
uniform vec2 select_square = vec2(-1.0, -1.0); // colonna, traversa (0..7) da accendere; -1 = nessuna
uniform vec3 select_color : source_color = vec3(1.0, 0.84, 0.18);
uniform float polish = 1.0;
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
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 inner = (uv - border) / (1.0 - 2.0 * border);
	float in_board = step(0.0, inner.x) * step(inner.x, 1.0) * step(0.0, inner.y) * step(inner.y, 1.0);
	vec2 g = inner * squares;
	vec2 cell = floor(g);
	float light = mod(cell.x + cell.y + first_light + 1.0, 2.0);
	vec2 m = uv * board_size; // metri

	// marmo: creste del rumore come vene, diverse per ogni casella
	float rnd = hall_hash21(cell + 4.0);
	vec2 vq = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * (m * vec2(0.5, 1.3) + rnd * 11.0);
	float n = hall_fbm(m * 1.1 + rnd * 7.0, 2.0 + detail);
	float v = abs(hall_fbm(vq + n * 1.5, 2.0 + detail) - 0.5) * 2.0;
	float aa = clamp(fwidth(v) * 3.0, 0.0, 1.0);
	float veins = pow(1.0 - v, mix(26.0, 8.0, aa)) * (1.0 - aa * 0.6);
	vec3 ivory = light_color * (0.92 + 0.12 * n) - vec3(0.25, 0.22, 0.18) * veins * 0.6;
	vec3 obsidian = dark_color * (0.8 + 0.5 * n) + gold * veins * 0.35;
	vec3 col = mix(obsidian, ivory, light);
	float vein_gold = veins * (1.0 - light);

	// fili d'oro tra le caselle e bordo della cornice
	vec2 fg = abs(fract(g + 0.5) - 0.5) / squares * board_size * (1.0 - 2.0 * border);
	float grid = hall_line(min(fg.x, fg.y), 0.012) * in_board;
	vec2 eb = min(uv, 1.0 - uv) * board_size;
	float frame_line = hall_line(abs(min(eb.x, eb.y) - border * board_size), 0.02) + hall_line(abs(min(eb.x, eb.y) - border * board_size * 0.35), 0.008);
	frame_line *= step(0.001, border);
	vec3 frame_col = dark_color * (0.6 + 0.4 * n) + gold * veins * 0.2;
	col = mix(frame_col, col, in_board);
	float gl = clamp(grid + frame_line, 0.0, 1.0);

	// casella accesa: bordo d'oro che pulsa e un velo di luce
	float sel = 0.0;
	if (select_square.x >= 0.0) {
		vec2 sc = fract(g) - 0.5;
		float is_sel = step(abs(cell.x - select_square.x) + abs(cell.y - select_square.y), 0.5) * in_board;
		float edge = hall_line(0.5 - max(abs(sc.x), abs(sc.y)), 0.04);
		sel = is_sel * (edge * 1.4 + 0.25) * (0.7 + 0.3 * sin(t * 5.0));
	}

	vec3 n_w = normalize(wnrm);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 R = reflect(-V, n_w);
	R.xz += (n - 0.5) * 0.04;
	vec3 env = hall_env(normalize(R), t);
	float F = hall_fresnel(n_w, V, 0.05);

	ALBEDO = mix(col, gold * 0.6, gl);
	METALLIC = gl * 0.85;
	ROUGHNESS = mix(0.1 + 0.12 * n, 0.25, gl);
	SPECULAR = 0.65;
	float gold_l = 0.45 + 0.55 * dot(env, vec3(0.5));
	EMISSION = env * (F * 1.3 + 0.04) * polish * (1.0 - gl) + gold * gl * gold_l * 0.7 + gold * vein_gold * 0.12
		+ select_color * sel + light_color * light * in_board * 0.035;
}
