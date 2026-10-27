// Il bong (#302): chi è fatto vede la realtà distorta. level va da 0 a 1 e cresce con la carica e poi col tempo:
// lo schermo ondeggia e respira, i colori si separano e girano, si vede doppio, i bordi si scuriscono.
// Gli effetti forti crescono col quadrato di level: appena fumato è leggero, poco prima di crollare è pesante
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform float level = 0.0;
uniform float t = 0.0;

void fragment() {
	float strong = level * level;
	// Il respiro: lo schermo si avvicina e si allontana piano dal centro
	vec2 uv = (SCREEN_UV - 0.5) * (1.0 - 0.025 * strong * (0.5 + 0.5 * sin(t * 1.3))) + 0.5;
	uv.x += sin(uv.y * 11.0 + t * 2.1) * (0.009 * level + 0.012 * strong);
	uv.y += cos(uv.x * 9.0 + t * 1.7) * (0.007 * level + 0.009 * strong);
	float sep = 0.007 * level + 0.01 * strong;
	vec3 c = vec3(texture(screen, uv + vec2(sep, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(sep, 0.0)).b);
	// La vista doppia: una copia spostata che gira lenta, sempre più marcata
	vec2 ghost = vec2(cos(t * 0.8), sin(t * 1.1)) * 0.018 * strong;
	c = mix(c, texture(screen, uv + ghost).rgb, 0.35 * strong);
	vec3 tint = 0.6 + 0.4 * cos(t * (0.9 + 0.8 * strong) + vec3(0.0, 2.1, 4.2));
	c = mix(c, c * tint * 1.35, 0.3 * level + 0.15 * strong);
	float v = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - level * 0.55 * smoothstep(0.3, 0.78, v);
	COLOR = vec4(c, 1.0);
}
