extends Node2D

signal shop_closed()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shop_panel: Control = $ShopLayer/ShopPanel
@onready var item_list: VBoxContainer = $ShopLayer/ShopPanel/VBox/ItemList
@onready var close_button: Button = $ShopLayer/ShopPanel/VBox/CloseButton

var _shop_open: bool = false
var _stock: Array = []
var _players_nearby: Array = []
var _hint_label: Label

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	shop_panel.visible = false
	close_button.pressed.connect(close_shop)
	_build_interact_area()
	_build_hint_label()

func _build_interact_area() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 64.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("players"):
			_players_nearby.append(b)
	)
	area.body_exited.connect(func(b: Node2D) -> void:
		_players_nearby.erase(b)
	)

func _build_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.text = "[E] Open Shop"
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.modulate = Color(0.7, 1.0, 0.9, 0.9)
	_hint_label.visible = false
	$ShopLayer.add_child(_hint_label)

func _process(_delta: float) -> void:
	var nearby := not _players_nearby.is_empty()
	var screen_pos := get_viewport().get_canvas_transform() * global_position

	_hint_label.visible = nearby and not _shop_open
	if nearby and not _shop_open:
		_hint_label.position = screen_pos + Vector2(-50.0, -72.0)
		if Input.is_action_just_pressed("interact"):
			open_shop()

	if _shop_open:
		shop_panel.position = screen_pos + Vector2(-160.0, -310.0)

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
		btn.custom_minimum_size = Vector2(0.0, 36.0)
		btn.add_theme_font_size_override("font_size", 15)
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
