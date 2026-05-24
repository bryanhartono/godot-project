shader_type canvas_item;

uniform vec2 player_screen_pos = vec2(400.0, 300.0);
uniform float vision_radius : hint_range(80.0, 400.0) = 160.0;
uniform float edge_softness : hint_range(10.0, 120.0) = 80.0;

void fragment() {
	float dist = distance(FRAGCOORD.xy, player_screen_pos);
	float alpha = smoothstep(vision_radius, vision_radius + edge_softness, dist);
	COLOR = vec4(0.02, 0.02, 0.05, alpha * 0.94);
}
