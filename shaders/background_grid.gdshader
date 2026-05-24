shader_type canvas_item;

uniform float grid_size : hint_range(10.0, 200.0) = 52.0;
uniform float line_width : hint_range(0.2, 4.0) = 1.1;
uniform vec4 bg_color : source_color = vec4(0.04, 0.055, 0.11, 1.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.28, 0.48, 1.0);
uniform float scroll_x : hint_range(-50.0, 50.0) = 9.0;
uniform float scroll_y : hint_range(-50.0, 50.0) = 4.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float line_opacity : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 pos = FRAGCOORD.xy;
	pos += vec2(TIME * scroll_x, TIME * scroll_y);

	vec2 grid = mod(pos, grid_size);
	float dx = min(grid.x, grid_size - grid.x);
	float dy = min(grid.y, grid_size - grid.y);
	float line = 1.0 - smoothstep(0.0, line_width, min(dx, dy));

	float pulse = sin(TIME * pulse_speed + (FRAGCOORD.x + FRAGCOORD.y) * 0.012) * 0.2 + 0.8;

	COLOR = mix(bg_color, vec4(line_color.rgb * pulse, 1.0), line * line_opacity);
}
