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
	# cost, max_hp, atk, move_range, atk_range, ability, sprite_row, sprite_file, speed(1-5)
	# ── Bruisers ──────────────────────────────────────────────────────
	_register(MonsterData.create(&"knight",  "Knight",  3,  8, 3, 3, 1, null,                               0, &"human_knight",    1))
	_register(MonsterData.create(&"soldier", "Soldier", 2,  6, 2, 2, 1, null,                               2, &"human_soldier",   3))
	_register(MonsterData.create(&"goblin",  "Goblin",  2,  7, 3, 2, 1, null,                               9, &"goblin_knight",   4))
	# ── Ranged ────────────────────────────────────────────────────────
	_register(MonsterData.create(&"orc",     "Orc",     2,  6, 2, 2, 2, null,                              11, &"goblin_soldier",  2))
	_register(MonsterData.create(&"archer",  "Archer",  2,  4, 2, 1, 3, null,                               4, &"human_archer",    2))
	# ── Assassins ─────────────────────────────────────────────────────
	_register(MonsterData.create(&"spider",  "Spider",  2,  5, 2, 4, 1, AbilityData.passive_poison(1),     17, &"",               4))
	_register(MonsterData.create(&"bat",     "Bat",     2,  4, 3, 4, 1, null,                              28, &"",               5))
	# ── Casters ───────────────────────────────────────────────────────
	_register(MonsterData.create(&"wraith",  "Wraith",  3,  5, 3, 2, 2, AbilityData.active_blink(4),       19, &"",               3))
	_register(MonsterData.create(&"imp",     "Imp",     3,  5, 3, 2, 1, AbilityData.active_aoe_strike(1),  21, &"",               4))
	# ── Tank ──────────────────────────────────────────────────────────
	_register(MonsterData.create(&"crab",    "Crab",    3, 10, 1, 2, 1, AbilityData.passive_tough(1),      24, &"spider",         1))
	_register(MonsterData.create(&"slime",   "Slime",   2,  8, 1, 1, 1, AbilityData.passive_tough(1),      22, &"slime",          1))
	# ── Support (high range; no passive) ─────────────────────────────
	_register(MonsterData.create(&"ghost",   "Ghost",   2,  5, 1, 3, 2, null,                              30, &"",               3))
	# ── Undead ────────────────────────────────────────────────────────
	_register(MonsterData.create(&"undead_soldier",  "Undead Soldier",  2,  7, 2, 2, 1, AbilityData.passive_tough(1), 16, &"undead_soldier",  2))
	_register(MonsterData.create(&"skeleton_archer", "Skeleton Archer", 2,  3, 3, 1, 3, null,                         22, &"skeleton_archer", 2))
	# ── Goblin variants ───────────────────────────────────────────────
	_register(MonsterData.create(&"goblin_grunt",   "Goblin Grunt",   1,  4, 2, 3, 1, null,                           8, &"goblin",          4))
	_register(MonsterData.create(&"goblin_slinger", "Goblin Slinger", 2,  3, 2, 2, 3, null,                          16, &"goblin_slingshot",3))
	# ── Human variants ────────────────────────────────────────────────
	_register(MonsterData.create(&"assassin", "Assassin", 3, 4, 4, 3, 1, null,                                        6, &"human_assasin",   5))
