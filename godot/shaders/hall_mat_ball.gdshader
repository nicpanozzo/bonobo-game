// Palloni: kind = 0 pallone da basket (cuoio arancione a puntini con le cuciture nere), kind = 1 pallone
// da spiaggia (spicchi di vinile lucido coi tappi bianchi ai poli). Il disegno sta nello spazio della
// sfera (direzione dal centro), quindi gira con il pallone e non ha cuciture di UV. Va su una SphereMesh
// con l'origine al centro.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform float kind = 0.0;
uniform vec3 leather : source_color = vec3(0.86, 0.36, 0.08);
uniform vec3 seam_color : source_color = vec3(0.05, 0.03, 0.03);
uniform vec3 c1 : source_color = vec3(1.0, 0.84, 0.18); // spicchi del pallone da spiaggia
uniform vec3 c2 : source_color = vec3(0.95, 0.2, 0.3);
uniform vec3 c3 : source_color = vec3(0.2, 0.55, 1.0);
uniform vec3 c4 : source_color = vec3(0.45, 0.22, 0.95);
uniform float motion = 1.0;
uniform float detail = 1.0;

varying vec3 ldir;

void vertex() {
	ldir = VERTEX;
}

void fragment() {
	float t = TIME * motion;
	vec3 p = normalize(ldir);
	vec3 col;
	float rough;
	float spec_k;
	if (kind < 0.5) {
		// cuciture: due cerchi massimi e le due curve laterali
		float w = 0.018;
		float s1 = abs(p.x);
		float s2 = abs(p.y);
		float s3 = abs(abs(p.z) - 0.62 - 0.28 * p.x * p.x);
		float seam = hall_line(min(min(s1, s2), s3), w);
		// buccia a puntini: un reticolo 3D di bozzi
		float k = 70.0;
		float peb = sin(p.x * k) * sin(p.y * k) * sin(p.z * k);
		float pebble = smoothstep(0.1, 0.7, abs(peb)) * detail;
		float far = clamp(fwidth(p.x * k) * 0.4, 0.0, 1.0);
		pebble = mix(pebble, 0.5, far);
		col = leather * (0.82 + 0.25 * pebble) * (0.92 + 0.16 * hall_noise(p.xy * 6.0 + p.z * 3.0));
		// le cuciture sono incassate: un'ombra ai lati
		float groove = hall_line(min(min(s1, s2), s3), w * 2.6) - seam;
		col *= 1.0 - groove * 0.35;
		col = mix(col, seam_color, seam);
		rough = 0.62 - 0.15 * pebble;
		spec_k = 0.25;
	} else {
		// sei spicchi attorno all'asse Y, tappi bianchi ai poli
		float a = atan(p.z, p.x) / 6.2831853 + 0.5;
		float seg = floor(a * 6.0);
		vec3 segc = seg < 1.0 ? c1 : seg < 2.0 ? vec3(0.97) : seg < 3.0 ? c2 : seg < 4.0 ? c3 : seg < 5.0 ? vec3(0.97) : c4;
		float edge = abs(fract(a * 6.0) - 0.5);
		float cap = smoothstep(0.88, 0.89, abs(p.y));
		col = mix(segc, vec3(0.97), cap);
		float button = smoothstep(0.985, 0.987, abs(p.y));
		col = mix(col, c1 * 0.8, button);
		// cucitura sottile tra gli spicchi
		col *= 1.0 - hall_line(0.5 - edge, 0.02) * 0.25 * (1.0 - cap);
		rough = 0.18;
		spec_k = 1.0;
	}
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 V = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 R = reflect(-V, n_w);
	float F = hall_fresnel(n_w, V, 0.05);
	vec3 env = hall_env(R, t);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	// il vinile riflette la sala, il cuoio appena; e un filo di luce propria perché non spariscano al buio
	EMISSION = env * (F * 1.2 + 0.05) * spec_k + col * 0.06;
}
