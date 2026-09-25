shader_type canvas_item;
// Translucent play field: faint cell lines, brighter intersections and a slow scan band.

uniform vec2 grid_size = vec2(24.0, 24.0);
uniform vec4 fill_color : source_color = vec4(0.01, 0.015, 0.05, 0.62);
uniform vec4 line_color : source_color = vec4(0.3, 0.55, 1.0, 1.0);

void fragment() {
	vec2 f = abs(fract(UV * grid_size) - 0.5);
	float line = smoothstep(0.46, 0.5, max(f.x, f.y));
	float cross = smoothstep(0.38, 0.5, f.x) * smoothstep(0.38, 0.5, f.y);
	float center = 1.0 - smoothstep(0.1, 0.75, length(UV - 0.5));
	float band = exp(-pow((UV.y - fract(TIME * 0.06)) * 18.0, 2.0));

	vec4 col = fill_color;
	col.rgb += line_color.rgb * (line * (0.05 + 0.05 * center) + cross * 0.22 + band * 0.035);
	col.a += band * 0.05;
	COLOR = col;
}
