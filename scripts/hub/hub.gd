# scripts/hub/hub.gd
extends Node

var _gems_label:     Label
var _trophies_label: Label
var _daily_btn:      Button
var _play_btn:       Button
var _ranked_btn:     Button

func _ready() -> void:
	_build_ui()
	PlayerProfile.tick_calendar()
	_refresh()

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas: CanvasLayer = $CanvasLayer

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.06, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    52)
	margin.add_theme_constant_override("margin_bottom", 36)
	canvas.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# — Title ————————————————————————————————————————————————
	var title := Label.new()
	title.text = "Monster Tactics"
	title.add_theme_font_size_override("font_size", 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var tagline := Label.new()
	tagline.text = "Battle. Collect. Conquer."
	tagline.add_theme_font_size_override("font_size", 17)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color(0.75, 0.62, 0.42)
	vbox.add_child(tagline)

	vbox.add_child(_make_separator())

	# — Stats panel ———————————————————————————————————————————
	var stats_panel := Panel.new()
	stats_panel.custom_minimum_size = Vector2(0, 64)
	vbox.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_margin.add_theme_constant_override("margin_left",   16)
	stats_margin.add_theme_constant_override("margin_right",  16)
	stats_margin.add_theme_constant_override("margin_top",    8)
	stats_margin.add_theme_constant_override("margin_bottom", 8)
	stats_panel.add_child(stats_margin)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 16)
	stats_margin.add_child(stats_row)

	_gems_label = Label.new()
	_gems_label.text = "💎 Gems: 0"
	_gems_label.add_theme_font_size_override("font_size", 20)
	_gems_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_row.add_child(_gems_label)

	var divider := VSeparator.new()
	stats_row.add_child(divider)

	_trophies_label = Label.new()
	_trophies_label.text = "🏆 Trophies: 0"
	_trophies_label.add_theme_font_size_override("font_size", 20)
	_trophies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trophies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_row.add_child(_trophies_label)

	# — Flexible spacer ——————————————————————————————————————
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# — Action buttons ————————————————————————————————————————
	_daily_btn = _make_btn("Daily Reward", 58)
	_daily_btn.pressed.connect(_on_daily_pressed)
	vbox.add_child(_daily_btn)

	var squad_btn := _make_btn("My Squad", 58)
	squad_btn.pressed.connect(_on_squad_pressed)
	vbox.add_child(squad_btn)

	# Play button uses a green accent to stand out
	_play_btn = _make_btn("Play", 72, Color(0.18, 0.50, 0.18))
	_play_btn.add_theme_font_size_override("font_size", 26)
	_play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(_play_btn)

	_ranked_btn = _make_btn("Ranked ★", 58)
	_ranked_btn.pressed.connect(_on_ranked_pressed)
	vbox.add_child(_ranked_btn)

func _make_btn(label_text: String, min_h: int = 58, accent: Color = Color(-1, -1, -1)) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if accent.r >= 0.0:
		btn.add_theme_stylebox_override("normal",  _color_btn_box(accent))
		btn.add_theme_stylebox_override("hover",   _color_btn_box(accent.lightened(0.20), true))
		btn.add_theme_stylebox_override("pressed", _color_btn_box(accent.darkened(0.25)))
	return btn

func _color_btn_box(color: Color, glow: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color     = color
	box.border_color = color.darkened(0.30)
	box.set_corner_radius_all(4)
	box.set_border_width_all(3)
	box.border_width_bottom = 4
	box.border_width_right  = 4
	box.content_margin_left   = 16.0
	box.content_margin_right  = 16.0
	box.content_margin_top    = 10.0
	box.content_margin_bottom = 10.0
	box.anti_aliasing = true
	box.shadow_offset = Vector2(2, 3)
	if glow:
		box.shadow_color = Color(0.20, 0.80, 0.20, 0.45)
		box.shadow_size  = 8
	else:
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
		box.shadow_size  = 4
	return box

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	return sep

# ── State ─────────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_gems_label.text     = "💎  %d" % PlayerProfile.gems
	_trophies_label.text = "🏆  %d" % PlayerProfile.trophies
	var squad_empty := PlayerProfile.squad.is_empty()
	_play_btn.disabled   = squad_empty
	_ranked_btn.disabled = squad_empty
	var status: Dictionary = PlayerProfile.daily_status()
	_daily_btn.text = "Daily Reward  —  READY!" if not status["claimed"] else "Daily Reward"

# ── Button handlers ───────────────────────────────────────────────────────────

func _on_daily_pressed() -> void:
	AudioManager.play_sfx(&"ui_click")
	PlayerProfile.tick_calendar()
	_show_calendar_popup()

func _on_squad_pressed() -> void:
	AudioManager.play_sfx(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/hub/squad_builder.tscn")

func _on_play_pressed() -> void:
	AudioManager.play_sfx(&"ui_click")
	var cfg       := MatchConfig.new()
	cfg.player_squad.assign(PlayerProfile.squad)
	cfg.enemy_squad   = SquadPicker.random_squad(PlayerProfile.BUDGET)
	cfg.difficulty    = 2
	Engine.set_meta("match_config", cfg)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _on_ranked_pressed() -> void:
	AudioManager.play_sfx(&"ui_click")
	var cfg       := MatchConfig.new()
	cfg.player_squad.assign(PlayerProfile.squad)
	cfg.enemy_squad   = RankedPool.pick_opponent(PlayerProfile.trophies)
	cfg.difficulty    = 2
	cfg.is_ranked     = true
	Engine.set_meta("match_config", cfg)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

# ── Calendar popup ────────────────────────────────────────────────────────────

func _show_calendar_popup() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.70)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Daily Reward"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var status:      Dictionary = PlayerProfile.daily_status()
	var current_day: int        = status["day"]
	var claimed:     bool       = status["claimed"]
	var missed:      Array      = status["missed"]

	for i in 7:
		var day_num := i + 1
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(52, 0)
		hbox.add_child(slot)

		var day_lbl := Label.new()
		day_lbl.text = "Day %d" % day_num
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(day_lbl)

		var reward: Dictionary = PlayerProfile.DAILY_REWARDS[i]
		var reward_lbl := Label.new()
		var has_mon: bool = reward.get("monster", false)
		var g: int = reward.get("gems", 0)
		if has_mon and g > 0:
			reward_lbl.text = "%d+Mon" % g
		elif has_mon:
			reward_lbl.text = "Monster"
		else:
			reward_lbl.text = "%dg" % g
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(reward_lbl)

		if day_num in missed:
			var buy_btn := Button.new()
			buy_btn.text     = "20g"
			buy_btn.disabled = PlayerProfile.gems < PlayerProfile.MISSED_DAY_COST
			buy_btn.pressed.connect(func():
				if PlayerProfile.buy_missed_day(day_num):
					layer.queue_free()
					_show_calendar_popup()
					_refresh()
			)
			slot.add_child(buy_btn)
		elif day_num == current_day and not claimed:
			var claim_btn := Button.new()
			claim_btn.text = "Claim!"
			claim_btn.pressed.connect(func():
				PlayerProfile.claim_daily()
				layer.queue_free()
				_refresh()
			)
			slot.add_child(claim_btn)
		elif day_num < current_day or (day_num == current_day and claimed):
			var done_lbl := Label.new()
			done_lbl.text = "Done"
			done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_child(done_lbl)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "Locked"
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_child(lock_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		layer.queue_free()
		_refresh()
	)
	vbox.add_child(close_btn)
