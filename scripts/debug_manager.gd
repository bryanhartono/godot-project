extends Node

var is_fast: bool = false
var is_invincible: bool = false
var is_noclip: bool = false

var _label: Label

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -340.0
	_label.offset_right = -12.0
	_label.offset_top = 12.0
	_label.offset_bottom = 160.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 20)
	_label.modulate = Color(1.0, 1.0, 0.25, 0.9)
	canvas.add_child(_label)
	_update_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			is_fast = !is_fast
		KEY_F2:
			is_invincible = !is_invincible
		KEY_F3:
			is_noclip = !is_noclip
			_apply_noclip()
		KEY_F4:
			_kill_local_player()
		KEY_F5:
			_reload_floor()
	_update_overlay()

func _apply_noclip() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			p.collision_mask = 0 if is_noclip else 5

func _kill_local_player() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.is_multiplayer_authority():
			p.debug_kill()
			break

func _reload_floor() -> void:
	if RunManager._run_active:
		RunManager.advance_floor()

func _update_overlay() -> void:
	var active: Array[String] = []
	if is_fast:       active.append("FAST")
	if is_invincible: active.append("INV")
	if is_noclip:     active.append("NOCLIP")

	var lines: Array[String] = []
	if active.size() > 0:
		lines.append("[ " + " | ".join(active) + " ]")
	lines.append("F1:Fast  F2:Inv  F3:Noclip")
	lines.append("F4:Kill  F5:NextFloor")
	_label.text = "\n".join(lines)
