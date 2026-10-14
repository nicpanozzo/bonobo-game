// Il bong (#302): chi è fatto vede la realtà distorta. level va da 0 a 1 e cresce col tempo:
// lo schermo ondeggia, i colori si separano e girano, i bordi si scuriscono
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform float level = 0.0;
uniform float t = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 11.0 + t * 2.1) * 0.009 * level;
	uv.y += cos(uv.x * 9.0 + t * 1.7) * 0.007 * level;
	float sep = 0.007 * level;
	vec3 c = vec3(texture(screen, uv + vec2(sep, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(sep, 0.0)).b);
	vec3 tint = 0.6 + 0.4 * cos(t * 0.9 + vec3(0.0, 2.1, 4.2));
	c = mix(c, c * tint * 1.35, 0.3 * level);
	float v = distance(SCREEN_UV, vec2(0.5));
	c *= 1.0 - level * 0.55 * smoothstep(0.3, 0.78, v);
	COLOR = vec4(c, 1.0);
}
