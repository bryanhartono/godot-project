extends CanvasLayer

@onready var floor_label: Label = $MarginContainer/VBox/FloorLabel
@onready var coin_label: Label = $MarginContainer/VBox/CoinLabel
@onready var hp_bars: HBoxContainer = $MarginContainer/VBox/HPBars

func _ready() -> void:
	RunManager.floor_changed.connect(_on_floor_changed)

func _process(_delta: float) -> void:
	coin_label.text = "Coins: %d" % MetaManager.coins
	_refresh_hp_bars()

func _on_floor_changed(floor_num: int) -> void:
	floor_label.text = "Floor %d" % floor_num

func _refresh_hp_bars() -> void:
	var players := get_tree().get_nodes_in_group("players")
	var bars := hp_bars.get_children()
	for i in bars.size():
		if i < players.size():
			bars[i].visible = true
			bars[i].max_value = players[i].max_hp
			bars[i].value = players[i].hp
		else:
			bars[i].visible = false
