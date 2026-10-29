// Neon: tubo acceso con l'anima quasi bianca e il colore sui fianchi, un respiro lento e, se chase > 0,
// le luci che corrono lungo UV.x come nelle insegne dei luna park. Non prende luce: è la luce.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform vec3 color : source_color = vec3(1.0, 0.84, 0.18);
uniform float intensity = 2.2; // oltre 1 per il bagliore (glow dell'Environment)
uniform float pulse = 0.15; // 0..1 quanto respira
uniform float pulse_speed = 1.6;
uniform float chase = 0.0; // 0..1 luci che corrono lungo UV.x
uniform float chase_count = 12.0; // quante luci lungo il pezzo
uniform float phase = 0.0; // sfasa più neon uguali
uniform float motion = 1.0;

void fragment() {
	float t = TIME * motion;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// anima bianca dove il tubo guarda la telecamera, colore pieno sui fianchi
	vec3 col = mix(color * 0.8, mix(color, vec3(1.0), 0.65), pow(facing, 2.0));
	float k = 1.0 - pulse + pulse * (0.5 + 0.5 * sin(t * pulse_speed + phase));
	if (chase > 0.0) {
		float c = fract(UV.x * chase_count - t * 1.5 + phase);
		k *= mix(1.0, 0.35 + 1.2 * smoothstep(0.0, 0.3, c) * smoothstep(0.9, 0.5, c), chase);
	}
	ALBEDO = col * intensity * k;
}
