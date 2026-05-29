# scripts/hub/hub.gd
extends Node

var _gems_label: Label
var _play_btn:   Button

func _ready() -> void:
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(vbox)

	var title := Label.new()
	title.text = "Monster Tactics"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	_gems_label = Label.new()
	vbox.add_child(_gems_label)

	var squad_btn := Button.new()
	squad_btn.text = "My Squad"
	squad_btn.pressed.connect(_on_squad_pressed)
	vbox.add_child(squad_btn)

	_play_btn = Button.new()
	_play_btn.text = "Play"
	_play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(_play_btn)

func _refresh() -> void:
	_gems_label.text   = "Gems: %d" % PlayerProfile.gems
	_play_btn.disabled = PlayerProfile.squad.is_empty()

func _on_squad_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/squad_builder.tscn")

func _on_play_pressed() -> void:
	var cfg            := MatchConfig.new()
	cfg.player_squad   = PlayerProfile.squad.duplicate()
	cfg.enemy_squad    = SquadPicker.random_squad(PlayerProfile.BUDGET)
	cfg.difficulty     = 2
	Engine.set_meta("match_config", cfg)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")
