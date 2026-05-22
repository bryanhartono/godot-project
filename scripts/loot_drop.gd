extends Area2D

signal picked_up()

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

const RARITY_WEIGHTS: Array = [60, 25, 12, 3]
const RARITY_COLORS: Array = [
	Color(0.7, 0.7, 0.7),
	Color(0.2, 0.9, 0.2),
	Color(0.2, 0.4, 1.0),
	Color(0.7, 0.2, 1.0),
]
const COIN_AMOUNTS: Array = [5, 10, 20, 50]
const HP_AMOUNTS: Array  = [10, 20, 35, 60]

var rarity: Rarity = Rarity.COMMON
var _picked_up: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	roll_rarity()

func roll_rarity(luck: float = 0.0) -> void:
	var weights: Array = RARITY_WEIGHTS.duplicate()
	weights[2] += int(luck * 2.0)
	weights[3] += int(luck)
	var total: int = 0
	for w in weights:
		total += w
	var roll := randi() % total
	var cumulative := 0
	for i in weights.size():
		cumulative += weights[i]
		if roll < cumulative:
			rarity = i as Rarity
			break
	modulate = RARITY_COLORS[rarity]

func _on_body_entered(body: Node2D) -> void:
	if _picked_up or not body.is_in_group("players"):
		return
	_picked_up = true
	body.heal(HP_AMOUNTS[rarity])
	MetaManager.add_coins(COIN_AMOUNTS[rarity])
	picked_up.emit()
	queue_free()
