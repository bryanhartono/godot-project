extends Node2D

signal shop_closed()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shop_panel: Control = $ShopPanel
@onready var item_list: VBoxContainer = $ShopPanel/VBox/ItemList
@onready var close_button: Button = $ShopPanel/VBox/CloseButton

var _shop_open: bool = false
var _stock: Array = []

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	shop_panel.visible = false
	close_button.pressed.connect(close_shop)

func open_shop() -> void:
	if _shop_open:
		return
	_shop_open = true
	_stock = _generate_stock()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("talk"):
		sprite.play("talk")
	_rebuild_item_list()
	shop_panel.visible = true

func _rebuild_item_list() -> void:
	for c in item_list.get_children():
		c.queue_free()
	for i in _stock.size():
		var btn := Button.new()
		btn.text = "%s  (%d coins)" % [_stock[i]["name"], _stock[i]["cost"]]
		btn.pressed.connect(_on_item_pressed.bind(i))
		item_list.add_child(btn)

func _on_item_pressed(index: int) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	if try_buy(index, players[0]):
		_rebuild_item_list()

func close_shop() -> void:
	_shop_open = false
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	shop_panel.visible = false
	shop_closed.emit()

func try_buy(index: int, player: Node) -> bool:
	if index >= _stock.size():
		return false
	var item: Dictionary = _stock[index]
	if MetaManager.coins < item["cost"]:
		return false
	MetaManager.add_coins(-item["cost"])
	_apply_item(item, player)
	_stock.remove_at(index)
	return true

func _generate_stock() -> Array:
	return [
		{"name": "Full Heal",  "cost": 30, "type": "heal", "value": 999},
		{"name": "Damage Up",  "cost": 50, "type": "stat", "stat": "damage_mult", "value": 0.25},
		{"name": "Speed Up",   "cost": 40, "type": "stat", "stat": "speed",       "value": 30.0},
	]

func _apply_item(item: Dictionary, player: Node) -> void:
	match item["type"]:
		"heal":
			player.heal(item["value"])
		"stat":
			match item["stat"]:
				"damage_mult":
					player.damage_mult = minf(player.damage_mult + item["value"], 3.0)
				"speed":
					player.speed = minf(player.speed + item["value"], 300.0)
