// Cono di luce di un faro (raggi divini): additivo, più forte vicino alla lampada, morbido ai bordi del
// cono e con un pulviscolo che fluttua nel fascio. Va su HallMaterials.god_ray_mesh() (cilindro aperto a
// tronco di cono, UV.y = 0 in cima alla lampada).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/hall_mat_common.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.88, 0.6);
uniform float intensity = 0.16;
uniform float dust = 1.0; // pulviscolo nel fascio
uniform float motion = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion;
	float facing = abs(dot(NORMAL, VIEW));
	// i bordi del cono, visti di taglio, spariscono: sembra un volume e non un tubo
	float soft = smoothstep(0.1, 0.9, facing);
	soft *= soft;
	float along = UV.y;
	float fall = (1.0 - along) * (1.0 - along) * 0.85 + 0.15;
	fall *= smoothstep(0.0, 0.15, along) * smoothstep(1.0, 0.7, along);
	float motes = 0.0;
	if (dust > 0.0) {
		vec2 dq = vec2(wpos.x + wpos.z, wpos.y) * 9.0 + vec2(t * 0.3, t * 0.45);
		vec2 di = floor(dq);
		vec2 df = fract(dq) - 0.5 - (hall_hash22(di) - 0.5) * 0.6;
		motes = step(0.9, hall_hash21(di + 1.3)) * smoothstep(0.08, 0.0, length(df)) * dust;
		motes *= 0.5 + 0.5 * sin(t * 2.0 + hall_hash21(di) * 6.28);
	}
	float stripes = 0.85 + 0.15 * hall_noise(vec2(atan(wpos.z, wpos.x) * 3.0, t * 0.2));
	ALBEDO = color * (fall * soft * intensity * stripes + motes * 0.6 * fall);
}
