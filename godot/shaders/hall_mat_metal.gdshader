// Metallo spazzolato (oro, acciaio, bronzo del gong): senza sonde di riflesso un metallo in Compatibility
// verrebbe nero, quindi il riflesso della sala (hall_env) entra come emissione, passato in una rampa
// di colore del metallo (ombre profonde, toni pieni, luci quasi bianche): così l'oro sembra sempre oro.
// Le righe della spazzolatura e un lampo che scorre lo fanno vivo; le luci vere aggiungono i riflessi.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0, 0.74, 0.32); // colore del metallo
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float brush = 1.0; // forza delle righe di spazzolatura
uniform float brush_density = 60.0; // righe per metro
uniform float reflect_strength = 1.0;
uniform float shine = 1.0; // il lampo di luce che scorre ogni tanto
uniform float bands = 1.0; // strisce di riflesso che scorrono con la telecamera (0 = metallo uniforme)
uniform float hammered = 0.0; // 0..1 ammaccature da martello (gong, trofei)
uniform float rings = 0.0; // 0..1 cerchi concentrici attorno all'asse Y della mesh (gong, piatti)
uniform float ring_radius = 1.0; // m, raggio del pezzo coi cerchi
uniform vec2 edge_grid = vec2(0.0); // (3, 2) su una BoxMesh: accende gli spigoli come smussi lucidati
uniform float strike = 0.0; // 0..1 il gong colpito: si accende e vibra, hall_view lo fa scendere a 0
uniform float motion = 1.0;
uniform float detail = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
}

// la rampa del metallo: dal quasi nero al pieno al riflesso bianco
vec3 metal_ramp(float l) {
	vec3 deep = tint * tint * tint * 0.08;
	vec3 mid = tint * 0.75;
	vec3 high = mix(tint, vec3(1.0, 0.97, 0.9), 0.35);
	vec3 c = mix(deep, mid, smoothstep(0.0, 0.5, l));
	c = mix(c, high * 1.2, smoothstep(0.55, 1.6, l));
	return c;
}

void fragment() {
	float t = TIME * motion;
	vec3 n_w = normalize(wnrm);
	vec3 a = abs(n_w);
	// righe orizzontali sui lati, concentriche sopra: come un pezzo tornito e spazzolato
	float coord = a.y > 0.7 ? length(wpos.xz) : wpos.y;
	float side = a.y > 0.7 ? atan(wpos.z, wpos.x) * 0.3 : (a.x > a.z ? wpos.z : wpos.x);
	float ur = length(lpos.xz) / ring_radius;
	if (rings > 0.0) {
		coord = mix(coord, ur * ring_radius, rings);
		side = mix(side, atan(lpos.z, lpos.x), rings);
	}
	float streak = hall_noise(vec2(coord * brush_density, side * 0.4));
	streak = mix(streak, hall_noise(vec2(coord * brush_density * 3.1, side * 4.0)), 0.4 * detail);
	// da lontano le righe si fondono: niente moiré
	streak = mix(streak, 0.5, clamp(fwidth(coord * brush_density) * 0.7, 0.0, 1.0));

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n_r = n_w;
	if (hammered > 0.0) {
		vec2 hq = lpos.xz * 7.0 / ring_radius;
		vec2 hd = fract(hq) - 0.5 - (hall_hash22(floor(hq)) - 0.5) * 0.4;
		n_r = normalize(n_w + (vec3(hd.x, hd.y, -hd.x) * hammered * 0.5));
	}
	vec3 R = reflect(-V, n_r);
	R.y += (streak - 0.5) * 0.2 * brush;
	// parallasse finta: punti diversi dello stesso lato vedono parti diverse della sala
	R.xz += sin(wpos.xz * 0.9 + wpos.y * 0.7) * 0.18;
	vec3 env = hall_env(normalize(R), t);
	float F = hall_fresnel(n_r, V, 0.6);
	float l = dot(env, vec3(0.45, 0.45, 0.25)) * 1.6 * reflect_strength * (0.75 + 0.5 * F);
	l *= 0.88 + 0.24 * streak * brush;
	// strisce di riflesso che scorrono quando si muove la telecamera: le facce piatte non restano piatte
	float band = 0.5 + 0.5 * sin((dot(wpos, vec3(0.37, 0.61, 0.23)) * 1.3 + R.y * 1.7 + R.x * 0.6) * 3.0);
	l *= mix(1.0, 0.6 + 0.8 * band * band * band, bands);
	if (edge_grid.x > 0.0) {
		vec2 fu = fract(UV * edge_grid);
		float ed = min(min(fu.x, 1.0 - fu.x), min(fu.y, 1.0 - fu.y));
		l += (1.0 - smoothstep(0.0, 0.03, ed)) * 0.9;
	}
	// lampo diagonale che attraversa il pezzo ogni ~7 s
	float s = fract((wpos.x + wpos.y * 1.3 + wpos.z * 0.6) * 0.12 - t * 0.14);
	float glint = exp(-pow((s - 0.5) * 26.0, 2.0)) * shine;
	l += glint * 0.9;
	vec3 col = metal_ramp(l + 0.12);
	if (rings > 0.0) {
		// gong: borchia lucida al centro, fascia martellata scura, anello lucido verso il bordo, bordo scuro
		float boss = 1.0 - smoothstep(0.14, 0.17, ur);
		float groove = hall_line(abs(ur - 0.21), 0.012) + hall_line(abs(ur - 0.8), 0.01);
		float patina = smoothstep(0.22, 0.3, ur) * smoothstep(0.78, 0.7, ur);
		float lip = smoothstep(0.94, 0.97, ur);
		float k = 1.0 + boss * 0.5 - patina * 0.45 - groove * 0.6 - lip * 0.5;
		col *= mix(1.0, k, rings);
	}
	col += tint * strike * (1.0 + 0.8 * sin(t * 40.0 - ur * 30.0));

	ALBEDO = tint * 0.35;
	METALLIC = 1.0;
	ROUGHNESS = clamp(roughness + (streak - 0.5) * 0.15 * brush, 0.05, 1.0);
	SPECULAR = 0.7;
	EMISSION = col;
}
