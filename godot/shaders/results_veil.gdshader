// Il velo dietro la fine partita (results_view.gd): l'arena sfocata e scurita d'inchiostro, così le scritte
// della partita (nomi, percentuali) non si leggono più sotto la classifica. amount va da 0 a 1 mentre entra.
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink : source_color = vec4(0.08, 0.05, 0.12, 1.0);
uniform float amount = 1.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);

void fragment() {
	vec2 o = vec2(6.0) / rect_size;
	vec3 b = textureLod(screen, SCREEN_UV, 3.0).rgb * 0.4;
	b += textureLod(screen, SCREEN_UV + vec2(o.x, o.y), 3.5).rgb * 0.15;
	b += textureLod(screen, SCREEN_UV + vec2(-o.x, o.y), 3.5).rgb * 0.15;
	b += textureLod(screen, SCREEN_UV + vec2(o.x, -o.y), 3.5).rgb * 0.15;
	b += textureLod(screen, SCREEN_UV + vec2(-o.x, -o.y), 3.5).rgb * 0.15;
	vec3 sharp = texture(screen, SCREEN_UV).rgb;
	vec3 c = mix(sharp, b, amount);
	// Inchiostro sopra, più scuro verso i bordi
	float v = distance(UV, vec2(0.5));
	float dark = amount * (0.62 + 0.25 * smoothstep(0.25, 0.8, v));
	COLOR = vec4(mix(c, ink.rgb, dark), 1.0);
}
