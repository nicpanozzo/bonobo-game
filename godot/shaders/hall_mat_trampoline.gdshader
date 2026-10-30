// Tappeto elastico: telo nero tecnico con cerchi giallo banana e cuciture a raggiera, e il bordo
// imbottito a spicchi giallo/viola. bounce (0..1, hall_view lo fa scendere dopo un salto) abbassa il
// centro del telo e manda un'onda di luce verso il bordo. Va su un PlaneMesh orizzontale con un po' di
// suddivisioni (HallMaterials.trampoline_mesh) perché il centro si pieghi davvero.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.84, 0.18);
uniform vec3 pad_color_2 : source_color = vec3(0.4, 0.18, 0.85);
uniform float bounce : hint_range(0.0, 1.0) = 0.0;
uniform float dip = 0.25; // m, quanto scende il centro con bounce = 1
uniform float mat_radius = 0.8; // raggio del telo (0..1 del quadrato), fuori c'è il bordo
uniform float motion = 1.0;

void vertex() {
	vec2 c = (UV - 0.5) * 2.0;
	float r = length(c) / mat_radius;
	VERTEX.y -= bounce * dip * clamp(1.0 - r * r, 0.0, 1.0);
}

void fragment() {
	float t = TIME * motion;
	vec2 c = (UV - 0.5) * 2.0;
	float rr = length(c);
	if (rr > 1.0) {
		discard;
	}
	float r = rr / mat_radius;
	float a = atan(c.y, c.x);
	vec3 col;
	float rough;
	vec3 emis = vec3(0.0);
	if (r < 1.0) {
		// telo: trama fitta a rombi, cerchi gialli e cuciture
		vec2 wq = c * 60.0;
		float weave = 0.5 + 0.5 * sin(wq.x + wq.y) * sin(wq.x - wq.y);
		col = vec3(0.025, 0.022, 0.03) * (0.8 + 0.4 * weave);
		float ring = hall_line(abs(r - 0.33), 0.025) + hall_line(abs(r - 0.66), 0.018) + hall_line(abs(r - 0.94), 0.02);
		float target = 1.0 - smoothstep(0.1, 0.12, r);
		col = mix(col, color * 0.85, clamp(ring + target, 0.0, 1.0));
		float stitches = hall_line(abs(fract(a / 6.2831853 * 16.0) - 0.5) - 0.5 + 0.02, 0.012) * step(0.12, r);
		stitches *= step(0.5, fract(r * 30.0));
		col += vec3(0.1) * stitches;
		rough = 0.55 - 0.2 * weave;
		// onda del salto
		float wave = exp(-pow((r - (1.0 - bounce)) * 8.0, 2.0)) * bounce;
		emis += color * (wave * 2.0 + target * 0.35 + ring * (0.3 + bounce * 0.6));
		emis += color * 0.05 * (0.5 + 0.5 * sin(t * 2.0));
	} else {
		// bordo imbottito: 12 spicchi alternati, bombati
		float k = (r - 1.0) / (1.0 / mat_radius - 1.0);
		float seg = step(0.5, fract(a / 6.2831853 * 12.0));
		col = mix(color, pad_color_2, seg);
		float bulge = sin(k * 3.14159);
		col *= 0.55 + 0.6 * bulge;
		float seam = hall_line(abs(fract(a / 6.2831853 * 12.0 + 0.5) - 0.5), 0.02) + hall_line(abs(fract(a / 6.2831853 * 12.0) - 0.5) - 0.5 + 0.01, 0.02);
		col *= 1.0 - clamp(seam, 0.0, 1.0) * 0.6;
		rough = 0.35;
		emis += col * (0.25 + 0.5 * bulge);
		vec3 V = normalize(CAMERA_POSITION_WORLD - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
		emis += hall_env(reflect(-V, vec3(0.0, 1.0, 0.0)), t) * 0.25 * bulge;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	EMISSION = emis;
}
