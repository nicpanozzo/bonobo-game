// Funzioni comuni ai materiali della sala d'attesa (hall_materials.gd): rumore senza texture e una
// "stanza finta" da riflettere, perché in Compatibility (WebGL2) non ci sono sonde di riflesso né SSR.
// Tutto ALU, niente letture dallo schermo: va bene anche sui telefoni.

// Colori della sala: giallo banana, oro, viola e blu notte
const vec3 HALL_BANANA = vec3(1.0, 0.84, 0.18);
const vec3 HALL_GOLD = vec3(1.0, 0.7, 0.28);
const vec3 HALL_PURPLE = vec3(0.42, 0.18, 0.95);
const vec3 HALL_NAVY = vec3(0.03, 0.025, 0.08);

float hall_hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hall_hash22(vec2 p) {
	float n = hall_hash21(p);
	return vec2(n, hall_hash21(p + n + 17.0));
}

float hall_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hall_hash21(i);
	float b = hall_hash21(i + vec2(1.0, 0.0));
	float c = hall_hash21(i + vec2(0.0, 1.0));
	float d = hall_hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Tre ottave bastano: di più non si vede a distanza di sala e costa sui telefoni
float hall_fbm(vec2 p, float octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		if (float(i) >= octaves) {
			break;
		}
		v += a * hall_noise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p;
		a *= 0.5;
	}
	return v;
}

// Linea sottile antialiasata: d è la distanza (stessa unità di w), fwidth evita lo sfarfallio da lontano
float hall_line(float d, float w) {
	float aa = max(fwidth(d), 1e-4);
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

// La sala riflessa: soffitto scuro con strisce di luce calda, una fascia dorata all'orizzonte (le insegne),
// un alone viola sopra e il faro in alto. dir è in coordinate del mondo.
vec3 hall_env(vec3 dir, float t) {
	float y = dir.y;
	vec3 col = mix(vec3(0.07, 0.04, 0.16), vec3(0.015, 0.01, 0.04), smoothstep(0.0, 0.9, y));
	col = mix(col, vec3(0.02, 0.015, 0.05), smoothstep(0.0, -0.6, y));
	col += HALL_GOLD * 0.55 * exp(-abs(y - 0.04) * 10.0);
	col += HALL_PURPLE * 0.45 * exp(-abs(y - 0.28) * 4.0);
	float az = atan(dir.z, dir.x);
	// pannelli luminosi sul soffitto, sei strisce attorno
	float strips = smoothstep(0.86, 0.97, cos(az * 6.0 + 0.4)) * smoothstep(0.32, 0.5, y) * smoothstep(0.92, 0.72, y);
	col += vec3(1.0, 0.92, 0.78) * strips * 1.6;
	// insegne colorate all'orizzonte
	float signs = smoothstep(0.7, 0.95, sin(az * 9.0 + 1.3)) * exp(-abs(y - 0.12) * 18.0);
	col += mix(HALL_BANANA, vec3(0.3, 0.75, 1.0), step(0.0, sin(az * 4.5))) * signs * 0.9;
	col += vec3(1.0, 0.9, 0.72) * smoothstep(0.965, 0.995, y) * 2.2;
	return col;
}

// Schlick: quanto riflette una superficie lucida guardata di sbieco
float hall_fresnel(vec3 n, vec3 v, float f0) {
	float c = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	float c2 = c * c;
	return f0 + (1.0 - f0) * c2 * c2 * c;
}
