shader_type canvas_item;

uniform float scanline_spacing : hint_range(2.0, 16.0) = 4.0;
uniform float scanline_darkness : hint_range(0.0, 0.5) = 0.12;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	COLOR = texture(TEXTURE, UV);

	// Subtle horizontal scanlines
	float scan = mod(FRAGCOORD.y, scanline_spacing);
	float dark = scan < 1.0 ? (1.0 - scanline_darkness) : 1.0;
	COLOR.rgb *= dark;

	// Mild vignette at room edges via UV distance from center
	vec2 dist = abs(UV - 0.5) * 2.0;
	float vignette = 1.0 - smoothstep(0.6, 1.0, max(dist.x, dist.y)) * vignette_strength;
	COLOR.rgb *= vignette;
}
