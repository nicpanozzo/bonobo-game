// Mezzo campo da basket: parquet d'acero a listoni sfalsati, laccato lucido (il riflesso finto della sala
// scorre sulla vernice), con le righe FIBA dipinte e l'area colorata. Le righe sono in proporzione al
// campo vero (15 x 14 m) scalate su court_size. Va su un PlaneMesh grande court_size: canestro sul lato
// a v = 0 (verso -z), metà campo a v = 1. lines = 0 dà solo il parquet.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec2 court_size = vec2(15.0, 14.0); // m, larghezza (x) e lunghezza (z) del PlaneMesh
uniform float lines = 1.0; // 1 = righe del campo dipinte
uniform vec3 wood_a : source_color = vec3(0.78, 0.5, 0.26);
uniform vec3 wood_b : source_color = vec3(0.62, 0.36, 0.17);
uniform vec3 line_color : source_color = vec3(0.97, 0.95, 0.9);
uniform vec3 paint_color : source_color = vec3(0.4, 0.16, 0.75); // l'area sotto canestro e il cerchio
uniform float paint_alpha = 0.85;
uniform float plank_width = 0.09; // m
uniform float plank_length = 1.8; // m
uniform float polish = 1.0;
uniform float motion = 1.0;
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// distanza da un segmento, per le righe dritte
float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	float t = TIME * motion;
	// metri sul campo: x da 0 a larghezza, z da 0 (fondo, canestro) a lunghezza (metà campo)
	vec2 p = UV * court_size;

	// Listoni: lungo z, sfalsati riga per riga
	float row = floor(p.x / plank_width);
	float rr = hall_hash21(vec2(row, 3.1));
	float zz = p.y / plank_length + rr;
	float plank = floor(zz);
	float pr = hall_hash21(vec2(row, plank));
	vec2 lp = vec2(fract(p.x / plank_width), fract(zz));
	vec3 wood = mix(wood_a, wood_b, pr * 0.8);
	// venatura: righe lunghe e mosse lungo il listone
	float grain = hall_noise(vec2(p.x * 60.0 + pr * 20.0, p.y * 1.6));
	if (detail > 0.0) {
		grain = mix(grain, hall_noise(vec2(p.x * 160.0, p.y * 4.0 + pr * 9.0)), 0.4);
	}
	float far = clamp(fwidth(p.x * 60.0) * 0.5, 0.0, 1.0);
	grain = mix(grain, 0.5, far);
	wood *= 0.82 + 0.36 * grain;
	// nodi rari, appena più scuri
	float knot = smoothstep(0.12, 0.0, length((lp - vec2(0.5, hall_hash21(vec2(plank, row)))) * vec2(1.0, 8.0))) * step(0.85, pr);
	wood *= 1.0 - knot * 0.25;
	// fughe sottili tra i listoni
	float seam_x = min(lp.x, 1.0 - lp.x) * plank_width;
	float seam_z = min(lp.y, 1.0 - lp.y) * plank_length;
	float seam = max(hall_line(seam_x, 0.0012), hall_line(seam_z, 0.002));
	wood *= 1.0 - seam * 0.45;

	// Righe FIBA, scalate sulla larghezza del campo
	float s = court_size.x / 15.0;
	float lw = 0.025 * s; // mezza larghezza della riga
	float cx = court_size.x * 0.5;
	vec2 hoop = vec2(cx, 1.575 * s);
	float d = 1e3;
	float paint = 0.0;
	if (lines > 0.0) {
		// bordo del campo
		vec2 e = min(p, court_size - p);
		d = min(d, min(e.x, e.y));
		// area: rettangolo 4,9 m fino alla lunetta a 5,8 m
		float kw = 2.45 * s;
		float kl = 5.8 * s;
		d = min(d, seg_d(p, vec2(cx - kw, 0.0), vec2(cx - kw, kl)));
		d = min(d, seg_d(p, vec2(cx + kw, 0.0), vec2(cx + kw, kl)));
		d = min(d, seg_d(p, vec2(cx - kw, kl), vec2(cx + kw, kl)));
		paint = step(abs(p.x - cx), kw) * step(p.y, kl);
		// lunetta del tiro libero
		d = min(d, abs(length(p - vec2(cx, kl)) - 1.8 * s));
		// semicerchio sotto canestro
		vec2 hp = p - hoop;
		d = min(d, hp.y > 0.0 ? abs(length(hp) - 1.25 * s) : 1e3);
		// linea da tre: dritta a 0,9 m dalle laterali, poi l'arco di 6,75 m
		float r3 = 6.75 * s;
		float side = cx - 0.9 * s;
		float y_join = hoop.y + sqrt(max(r3 * r3 - side * side, 0.0));
		float arc = abs(length(hp) - r3);
		float straight = abs(abs(p.x - cx) - side);
		d = min(d, p.y > y_join ? (abs(p.x - cx) < side ? arc : 1e3) : (p.y > 0.0 ? straight : 1e3));
		// cerchio di centrocampo, metà dentro il campo
		vec2 cc = p - vec2(cx, court_size.y);
		d = min(d, abs(length(cc) - 1.8 * s));
		paint = max(paint, step(length(cc), 1.8 * s) * 0.9);
	}
	float line = hall_line(d, lw) * lines;
	vec3 col = mix(wood, mix(wood * 0.3, paint_color, 0.85), paint * paint_alpha * lines);
	col = mix(col, line_color, line);

	vec3 n_w = normalize(wnrm);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 R = reflect(-V, n_w);
	R.xz += (grain - 0.5) * 0.04;
	float F = hall_fresnel(n_w, V, 0.05);
	vec3 refl = hall_env(normalize(R), t) * (F * 1.4 + 0.04) * polish;
	// riflesso caldo dei fari che scorre lungo le assi
	float sheen = exp(-pow((fract(dot(p, vec2(0.03, 0.06)) - t * 0.03) - 0.5) * 18.0, 2.0)) * 0.04 * polish;

	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.3, grain) + seam * 0.4;
	SPECULAR = 0.6;
	EMISSION = refl * (1.0 - seam) + vec3(1.0, 0.85, 0.6) * sheen + col * 0.04;
}
