extends Node2D

signal shop_closed()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shop_panel: Control = $ShopPanel

var _shop_open: bool = false
var _stock: Array = []

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	shop_panel.visible = false

func open_shop() -> void:
	if _shop_open:
		return
	_shop_open = true
	_stock = _generate_stock()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("talk"):
		sprite.play("talk")
	shop_panel.visible = true

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
		{"name": "Damage Up",  "cost": 50, "type": "stat", "stat": "damage_mult", "value": 0.2},
		{"name": "Speed Up",   "cost": 40, "type": "stat", "stat": "speed_mult",  "value": 0.15},
	]

func _apply_item(item: Dictionary, player: Node) -> void:
	match item["type"]:
		"heal":
			player.heal(item["value"])
		"stat":
			pass  # stat modifiers wired up in Phase 3
