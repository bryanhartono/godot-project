# scripts/battle/skirmish_setup.gd
extends Node

## Skirmish entry screen. Handles difficulty selection, squad preview, and match start.

var _difficulty: int = 2   # 1=Easy 2=Normal 3=Hard
var _player_squad: Array[MonsterData] = []

var _squad_label: Label
var _diff_label:  Label

func _ready() -> void:
    var vbox := $CanvasLayer/VBox
    _squad_label = vbox.get_node("SquadLabel") as Label
    _diff_label  = vbox.get_node("DiffLabel")  as Label
    (vbox.get_node("RerollBtn") as Button).pressed.connect(_on_reroll_pressed)
    (vbox.get_node("EasyBtn")   as Button).pressed.connect(_on_easy_pressed)
    (vbox.get_node("NormalBtn") as Button).pressed.connect(_on_normal_pressed)
    (vbox.get_node("HardBtn")   as Button).pressed.connect(_on_hard_pressed)
    (vbox.get_node("StartBtn")  as Button).pressed.connect(_on_start_pressed)
    _player_squad = SquadPicker.random_squad(10)
    _refresh_squad_label()
    _refresh_diff_label()

func _on_easy_pressed()   -> void: _difficulty = 1; _refresh_diff_label()
func _on_normal_pressed() -> void: _difficulty = 2; _refresh_diff_label()
func _on_hard_pressed()   -> void: _difficulty = 3; _refresh_diff_label()

func _on_reroll_pressed() -> void:
    _player_squad = SquadPicker.random_squad(10)
    _refresh_squad_label()

func _on_start_pressed() -> void:
    var cfg         := MatchConfig.new()
    cfg.player_squad = _player_squad
    cfg.enemy_squad  = SquadPicker.random_squad(10)
    cfg.difficulty   = _difficulty
    Engine.set_meta("match_config", cfg)
    get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _refresh_squad_label() -> void:
    if _squad_label == null:
        return
    var names := []
    for m in _player_squad:
        names.append(m.display_name)
    _squad_label.text = "Your squad: " + ", ".join(names)

func _refresh_diff_label() -> void:
    if _diff_label == null:
        return
    var labels := {1: "Easy", 2: "Normal", 3: "Hard"}
    _diff_label.text = "Difficulty: " + labels[_difficulty]
