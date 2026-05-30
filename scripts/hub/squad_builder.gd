# scripts/hub/squad_builder.gd
extends Node

const BUDGET := 10

var _working_squad: Array[MonsterData] = []

@onready var _budget_label: Label         = $CanvasLayer/VBoxContainer/TopBar/BudgetLabel
@onready var _card_grid:    GridContainer = $CanvasLayer/VBoxContainer/Scroll/CardGrid
@onready var _squad_strip:  HBoxContainer = $CanvasLayer/VBoxContainer/SquadStrip

var _card_btns: Dictionary = {}   # MonsterData -> Button

func _ready() -> void:
	_working_squad = PlayerProfile.squad.duplicate()
	$CanvasLayer/VBoxContainer/TopBar/BackBtn.pressed.connect(_on_back_pressed)
	_populate_cards()
	_refresh()

func _populate_cards() -> void:
	for om: OwnedMonster in PlayerProfile.owned:
		var btn := Button.new()
		btn.text                = "%s\nCost: %d" % [om.data.display_name, om.data.cost]
		btn.custom_minimum_size = Vector2(120, 60)
		btn.pressed.connect(_on_card_pressed.bind(om.data))
		_card_grid.add_child(btn)
		_card_btns[om.data] = btn

func _on_card_pressed(data: MonsterData) -> void:
	if data in _working_squad:
		_working_squad.erase(data)
	else:
		if _working_cost() + data.cost <= BUDGET:
			_working_squad.append(data)
	_refresh()

func _on_back_pressed() -> void:
	PlayerProfile.set_squad(_working_squad)
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

func _working_cost() -> int:
	var total := 0
	for m in _working_squad:
		total += m.cost
	return total

func _refresh() -> void:
	var used := _working_cost()
	_budget_label.text = "Budget: %d/%d" % [used, BUDGET]

	for data: MonsterData in _card_btns:
		var btn: Button = _card_btns[data]
		var selected    := data in _working_squad
		btn.disabled    = not selected and (_working_cost() + data.cost > BUDGET)
		btn.modulate    = Color(0.6, 1.0, 0.6) if selected else Color(1, 1, 1)

	for child in _squad_strip.get_children():
		child.queue_free()
	for m: MonsterData in _working_squad:
		var lbl := Label.new()
		lbl.text = "%s(%d)" % [m.display_name, m.cost]
		_squad_strip.add_child(lbl)
