// Ologramma: luce additiva con i bordi accesi (fresnel), righe di scansione che salgono, un tremolio
// e ogni tanto una banda che "salta". Per le sbarre della gabbia dei bot, il raggio del teletrasporto e
// le scritte sospese. fade_top sfuma verso l'alto (raggi su CylinderMesh: UV.y = 0 in cima).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(0.3, 0.85, 1.0);
uniform float intensity = 1.2;
uniform float fresnel_power = 2.0;
uniform float scan_density = 26.0; // righe per metro
uniform float scan_speed = 0.6; // m/s verso l'alto
uniform float fade_top = 1.0; // 1 = sparisce verso UV.y = 0, 0 = uniforme
uniform float flicker = 0.12;
uniform float motion = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion;
	float facing = abs(dot(NORMAL, VIEW));
	float fres = pow(1.0 - facing, fresnel_power);
	float scan = 0.5 + 0.5 * sin((wpos.y - t * scan_speed) * scan_density * 6.2831853);
	scan = mix(0.55, 1.0, scan * scan);
	float aa = clamp(fwidth(wpos.y * scan_density) * 1.5, 0.0, 1.0);
	scan = mix(scan, 0.78, aa);
	// banda più chiara che sale ogni ~3 s
	float band = exp(-pow((fract(wpos.y * 0.25 - t * 0.33) - 0.5) * 18.0, 2.0));
	// sfarfallio: rumore lento a gradini
	float fl = 1.0 - flicker + flicker * hall_hash21(vec2(floor(t * 14.0), 3.0));
	float glitch = step(0.96, hall_hash21(vec2(floor(t * 6.0), floor(wpos.y * 4.0))));
	float v = mix(1.0, smoothstep(0.0, 0.9, UV.y), fade_top);
	vec3 hot = mix(color, vec3(1.0), 0.5);
	vec3 col = color * (0.18 + fres * 1.3) * scan + hot * band * 0.5 + color * glitch * 0.6;
	ALBEDO = col * intensity * fl * v;
}
