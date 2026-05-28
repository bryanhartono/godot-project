## Autoload: all monster definitions. Access via the global singleton MonsterDB.
## No class_name — avoids Godot autoload-vs-class-constructor ambiguity.
extends Node

var _all: Dictionary = {}  # StringName -> MonsterData

func _ready() -> void:
	_register_all()

func get_monster(id: StringName) -> MonsterData:
	return _all.get(id, null)

func all_monsters() -> Array[MonsterData]:
	var out: Array[MonsterData] = []
	for m in _all.values():
		out.append(m)
	return out

func _register(data: MonsterData) -> void:
	_all[data.id] = data

func _register_all() -> void:
	# cost, max_hp, atk, move_range, atk_range, ability, sprite_row, sprite_file
	# ── Bruisers ──────────────────────────────────────────────────────
	_register(MonsterData.create(&"knight",  "Knight",  3,  8, 3, 3, 1, null,                               0, &"human_knight"))
	_register(MonsterData.create(&"soldier", "Soldier", 2,  6, 2, 2, 1, null,                               2, &"human_soldier"))
	_register(MonsterData.create(&"goblin",  "Goblin",  2,  7, 3, 2, 1, null,                               9, &"goblin_knight"))
	# ── Ranged ────────────────────────────────────────────────────────
	_register(MonsterData.create(&"orc",     "Orc",     2,  6, 2, 2, 2, null,                              11, &"goblin_soldier"))
	_register(MonsterData.create(&"archer",  "Archer",  2,  4, 2, 1, 3, null,                               4, &"human_archer"))
	# ── Assassins ─────────────────────────────────────────────────────
	_register(MonsterData.create(&"spider",  "Spider",  2,  5, 2, 4, 1, AbilityData.passive_poison(1),     17))
	_register(MonsterData.create(&"bat",     "Bat",     2,  4, 3, 4, 1, null,                              28))
	# ── Casters ───────────────────────────────────────────────────────
	_register(MonsterData.create(&"wraith",  "Wraith",  3,  5, 3, 2, 2, AbilityData.active_blink(4),       19))
	_register(MonsterData.create(&"imp",     "Imp",     3,  5, 3, 2, 1, AbilityData.active_aoe_strike(1),  21))
	# ── Tank ──────────────────────────────────────────────────────────
	_register(MonsterData.create(&"crab",    "Crab",    3, 10, 1, 2, 1, AbilityData.passive_tough(1),      24))
	# ── Support (high range; no passive) ─────────────────────────────
	_register(MonsterData.create(&"ghost",   "Ghost",   2,  5, 1, 3, 2, null,                              30))
