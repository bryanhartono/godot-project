# scripts/hub/hub.gd
extends Node

@onready var _gems_label:    Label  = $CanvasLayer/CenterContainer/VBoxContainer/GemsLabel
@onready var _trophies_label: Label = $CanvasLayer/CenterContainer/VBoxContainer/TrophiesLabel
@onready var _daily_btn:     Button = $CanvasLayer/CenterContainer/VBoxContainer/DailyBtn
@onready var _play_btn:      Button = $CanvasLayer/CenterContainer/VBoxContainer/PlayBtn
@onready var _ranked_btn:    Button = $CanvasLayer/CenterContainer/VBoxContainer/RankedBtn

func _ready() -> void:
	PlayerProfile.tick_calendar()
	$CanvasLayer/CenterContainer/VBoxContainer/DailyBtn.pressed.connect(_on_daily_pressed)
	$CanvasLayer/CenterContainer/VBoxContainer/SquadBtn.pressed.connect(_on_squad_pressed)
	$CanvasLayer/CenterContainer/VBoxContainer/PlayBtn.pressed.connect(_on_play_pressed)
	$CanvasLayer/CenterContainer/VBoxContainer/RankedBtn.pressed.connect(_on_ranked_pressed)
	_refresh()

func _refresh() -> void:
	_gems_label.text    = "Gems: %d" % PlayerProfile.gems
	_trophies_label.text = "Trophies: %d" % PlayerProfile.trophies
	var squad_empty := PlayerProfile.squad.is_empty()
	_play_btn.disabled   = squad_empty
	_ranked_btn.disabled = squad_empty
	var status: Dictionary = PlayerProfile.daily_status()
	_daily_btn.text = "Daily Reward — READY" if not status["claimed"] else "Daily Reward"

func _on_daily_pressed() -> void:
	PlayerProfile.tick_calendar()
	_show_calendar_popup()

func _on_squad_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/squad_builder.tscn")

func _on_play_pressed() -> void:
	var cfg          := MatchConfig.new()
	cfg.player_squad  = PlayerProfile.squad.duplicate()
	cfg.enemy_squad   = SquadPicker.random_squad(PlayerProfile.BUDGET)
	cfg.difficulty    = 2
	Engine.set_meta("match_config", cfg)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _on_ranked_pressed() -> void:
	var cfg          := MatchConfig.new()
	cfg.player_squad  = PlayerProfile.squad.duplicate()
	cfg.enemy_squad   = RankedPool.pick_opponent(PlayerProfile.trophies)
	cfg.difficulty    = 2
	cfg.is_ranked     = true
	Engine.set_meta("match_config", cfg)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _show_calendar_popup() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
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
		slot.custom_minimum_size = Vector2(50, 0)
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
