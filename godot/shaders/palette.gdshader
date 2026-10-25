// Colori alternativi dei lottatori (E11 passo C): due giocatori con lo stesso personaggio si distinguono.
// world_view.gd disegna tutto con questo materiale; uno sprite da ricolorare arriva con il rosso del
// modulate oltre 1 (2 + spostamento della tinta, da 0 a 1), che nessun altro disegno usa.
// I pixel quasi grigi (contorni, bianchi, neri) restano com'erano.
// Il verde oltre 1 (2 + quanto, da 0 a 1) schiarisce lo sprite verso il bianco: il lampo del colpo caricato.
// Il blu oltre 1 (2 + spessore in texel / 8) fa il contorno uniforme dei lottatori: i pixel pieni vicini al bordo
// della sagoma diventano INK, così sprite fatti in modi diversi hanno tutti lo stesso tratto.
shader_type canvas_item;

const vec3 INK = vec3(0.1, 0.08, 0.12);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	if (tint.r > 1.5 || tint.g > 1.5 || tint.b > 1.5) {
		vec4 tex = texture(TEXTURE, UV);
		vec3 rgb = tex.rgb;
		if (tint.r > 1.5) {
			vec3 hsv = rgb2hsv(rgb);
			if (hsv.y > 0.2) {
				hsv.x = fract(hsv.x + tint.r - 2.0);
			}
			rgb = hsv2rgb(hsv);
		}
		if (tint.b > 1.5 && tex.a > 0.0) {
			// Contorno interno: otto letture a distanza w. Dentro la sagoma, così non pesca nei fotogrammi accanto
			vec2 w = TEXTURE_PIXEL_SIZE * (tint.b - 2.0) * 8.0;
			float a = min(texture(TEXTURE, UV + vec2(w.x, 0.0)).a, texture(TEXTURE, UV - vec2(w.x, 0.0)).a);
			a = min(a, min(texture(TEXTURE, UV + vec2(0.0, w.y)).a, texture(TEXTURE, UV - vec2(0.0, w.y)).a));
			a = min(a, min(texture(TEXTURE, UV + w * 0.7).a, texture(TEXTURE, UV - w * 0.7).a));
			a = min(a, min(texture(TEXTURE, UV + vec2(w.x, -w.y) * 0.7).a, texture(TEXTURE, UV + vec2(-w.x, w.y) * 0.7).a));
			rgb = mix(rgb, INK, 1.0 - smoothstep(0.1, 0.5, a));
		}
		if (tint.g > 1.5) {
			rgb = mix(rgb, vec3(1.0, 0.97, 0.85), clamp(tint.g - 2.0, 0.0, 1.0));
		}
		COLOR = vec4(rgb, tex.a * tint.a);
	}
}
