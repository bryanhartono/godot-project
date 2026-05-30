# scripts/ui/app_theme.gd
extends Node

## Warm retro global theme — applied to the root Window so all controls inherit it.

func _ready() -> void:
	get_tree().root.theme = _build_theme()

func _build_theme() -> Theme:
	var theme := Theme.new()
	var font: FontFile = load("res://assets/Fonts/Kenney Pixel.ttf")
	theme.default_font      = font
	theme.default_font_size = 22

	theme.set_stylebox("normal",   "Button", _btn_box(Color(0.545, 0.369, 0.173)))
	theme.set_stylebox("hover",    "Button", _btn_box(Color(0.769, 0.529, 0.243)))
	theme.set_stylebox("pressed",  "Button", _btn_box(Color(0.353, 0.227, 0.094)))
	theme.set_stylebox("disabled", "Button", _btn_box(Color(0.33, 0.24, 0.13)))
	theme.set_stylebox("focus",    "Button", _focus_box())

	theme.set_color("font_color",          "Button", Color(0.961, 0.871, 0.702))
	theme.set_color("font_hover_color",    "Button", Color(1.00,  0.950, 0.850))
	theme.set_color("font_pressed_color",  "Button", Color(0.90,  0.780, 0.550))
	theme.set_color("font_disabled_color", "Button", Color(0.55,  0.450, 0.320))

	theme.set_color("font_color", "Label", Color(0.961, 0.871, 0.702))

	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.18, 0.10, 0.04, 0.92)
	panel_box.set_corner_radius_all(6)
	theme.set_stylebox("panel", "Panel", panel_box)

	return theme

func _btn_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = color
	box.border_color = color.darkened(0.35)
	box.set_corner_radius_all(6)
	box.set_border_width_all(2)
	box.content_margin_left   = 14.0
	box.content_margin_right  = 14.0
	box.content_margin_top    = 8.0
	box.content_margin_bottom = 8.0
	box.anti_aliased          = true
	return box

func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = Color(0, 0, 0, 0)
	box.border_color = Color(0.9, 0.7, 0.3)
	box.set_corner_radius_all(6)
	box.set_border_width_all(2)
	return box
