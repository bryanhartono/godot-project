# scripts/ui/app_theme.gd
extends Node

## Warm retro global theme — applied to the root Window so all controls inherit it.

func _ready() -> void:
	get_tree().root.theme = _build_theme()

func _build_theme() -> Theme:
	var theme := Theme.new()
	var font: FontFile = load("res://assets/Fonts/Kenney Pixel Square.ttf")
	theme.default_font      = font
	theme.default_font_size = 20

	theme.set_stylebox("normal",   "Button", _btn_box(Color(0.545, 0.369, 0.173)))
	theme.set_stylebox("hover",    "Button", _btn_box(Color(0.769, 0.529, 0.243), true))
	theme.set_stylebox("pressed",  "Button", _btn_pressed(Color(0.353, 0.227, 0.094)))
	theme.set_stylebox("disabled", "Button", _btn_box(Color(0.28, 0.20, 0.10)))
	theme.set_stylebox("focus",    "Button", _focus_box())

	theme.set_color("font_color",          "Button", Color(0.961, 0.871, 0.702))
	theme.set_color("font_hover_color",    "Button", Color(1.00,  0.970, 0.880))
	theme.set_color("font_pressed_color",  "Button", Color(0.85,  0.720, 0.480))
	theme.set_color("font_disabled_color", "Button", Color(0.50,  0.400, 0.280))

	theme.set_color("font_color", "Label", Color(0.961, 0.871, 0.702))

	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.14, 0.08, 0.03, 0.95)
	panel_box.border_color = Color(0.4, 0.25, 0.10, 0.8)
	panel_box.set_corner_radius_all(4)
	panel_box.set_border_width_all(2)
	panel_box.shadow_color  = Color(0.0, 0.0, 0.0, 0.5)
	panel_box.shadow_offset = Vector2(2, 3)
	panel_box.shadow_size   = 3
	theme.set_stylebox("panel", "Panel", panel_box)

	return theme

func _btn_box(color: Color, glow: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = color
	box.border_color = color.lightened(0.25)
	box.set_corner_radius_all(4)
	box.set_border_width_all(3)
	# Darker bottom/right border to simulate raised 3D look
	box.border_width_bottom = 4
	box.border_width_right  = 4
	box.border_color        = color.darkened(0.30)
	# Bright top-left highlight via expand margins
	box.expand_margin_left   = 0.0
	box.expand_margin_top    = 0.0
	box.content_margin_left   = 16.0
	box.content_margin_right  = 16.0
	box.content_margin_top    = 10.0
	box.content_margin_bottom = 10.0
	box.anti_aliasing = true
	# Drop shadow for depth
	box.shadow_color  = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_offset = Vector2(2, 3)
	box.shadow_size   = 4
	if glow:
		box.shadow_color  = Color(0.90, 0.65, 0.20, 0.5)
		box.shadow_size   = 6
	return box

func _btn_pressed(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = color
	box.border_color = color.darkened(0.40)
	box.set_corner_radius_all(4)
	box.set_border_width_all(3)
	box.border_width_top  = 4
	box.border_width_left = 4
	box.content_margin_left   = 16.0
	box.content_margin_right  = 16.0
	box.content_margin_top    = 12.0
	box.content_margin_bottom = 8.0
	box.anti_aliasing = true
	# No shadow when pressed (sunken look)
	return box

func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = Color(0, 0, 0, 0)
	box.border_color = Color(0.95, 0.78, 0.25, 0.9)
	box.set_corner_radius_all(4)
	box.set_border_width_all(2)
	return box
