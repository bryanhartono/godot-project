extends CanvasLayer

@onready var floor_label: Label = $MarginContainer/VBox/FloorLabel
@onready var coin_label: Label = $MarginContainer/VBox/CoinLabel
@onready var hp_bars: HBoxContainer = $MarginContainer/VBox/HPBars
@onready var combo_label: Label = $MarginContainer/VBox/ComboLabel

func _ready() -> void:
	RunManager.floor_changed.connect(_on_floor_changed)
	RunManager.combo_changed.connect(_on_combo_changed)
	combo_label.visible = false

func _process(_delta: float) -> void:
	coin_label.text = "Coins: %d" % MetaManager.coins
	_refresh_hp_bars()

func _on_floor_changed(floor_num: int) -> void:
	floor_label.text = "Floor %d" % floor_num

func _on_combo_changed(count: int) -> void:
	if count <= 1:
		combo_label.visible = false
	else:
		combo_label.visible = true
		combo_label.text = "Combo x%d  (+%d%%)" % [count, int((RunManager.get_combo_multiplier() - 1.0) * 100)]

func _refresh_hp_bars() -> void:
	var players := get_tree().get_nodes_in_group("players")
	var bars := hp_bars.get_children()
	for i in bars.size():
		if i < players.size():
			bars[i].visible = true
			bars[i].max_value = players[i].max_hp
			bars[i].value = players[i].hp
			bars[i].modulate = Color(0.4, 0.4, 1.0, 0.6) if players[i].is_ghost else Color.WHITE
		else:
			bars[i].visible = false
