shader_type canvas_item;
// Slowly drifting two-tone nebula over deep space, darkened toward the edges.

uniform vec4 deep : source_color = vec4(0.012, 0.01, 0.04, 1.0);
uniform vec4 color_a : source_color = vec4(0.32, 0.08, 0.52, 1.0);
uniform vec4 color_b : source_color = vec4(0.04, 0.22, 0.45, 1.0);
uniform float speed = 0.012;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(1.45, 1.0) * 2.2;
	float t = TIME * speed;
	float n1 = fbm(uv + vec2(t, t * 0.6));
	float n2 = fbm(uv * 1.6 - vec2(t * 0.8, -t) + n1 * 1.3);
	vec3 col = deep.rgb;
	col = mix(col, color_a.rgb, smoothstep(0.42, 0.95, n2) * 0.6);
	col = mix(col, color_b.rgb, smoothstep(0.5, 0.95, n1) * 0.5);
	float vignette = 1.0 - smoothstep(0.35, 0.95, length(UV - 0.5));
	col *= 0.45 + 0.55 * vignette;
	COLOR = vec4(col, 1.0);
}
