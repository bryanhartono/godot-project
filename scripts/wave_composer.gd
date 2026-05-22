class_name WaveComposer
extends RefCounted

# Each entry: cost, floor_unlock, hp, speed
const ENEMY_TYPES: Array = [
	{"cost": 2, "floor_unlock": 1, "hp": 20,  "speed": 50.0},
	{"cost": 3, "floor_unlock": 2, "hp": 25,  "speed": 40.0},
	{"cost": 4, "floor_unlock": 3, "hp": 15,  "speed": 80.0},
	{"cost": 5, "floor_unlock": 4, "hp": 60,  "speed": 30.0},
	{"cost": 7, "floor_unlock": 5, "hp": 40,  "speed": 55.0},
]

const ELITE_MODIFIERS: Array = ["shielded", "speedy", "exploder", "armored"]
const ELITE_CHANCE := 0.15

func compose(floor_number: int, budget: int, rng: RandomNumberGenerator) -> Array:
	var available: Array = ENEMY_TYPES.filter(
		func(e: Dictionary) -> bool: return e["floor_unlock"] <= floor_number
	)
	var result: Array = []
	var remaining := budget

	while remaining > 0:
		var affordable: Array = available.filter(
			func(e: Dictionary) -> bool: return e["cost"] <= remaining
		)
		if affordable.is_empty():
			break
		var pick: Dictionary = affordable[rng.randi() % affordable.size()].duplicate()
		if floor_number >= 3 and rng.randf() < ELITE_CHANCE:
			pick["elite"] = ELITE_MODIFIERS[rng.randi() % ELITE_MODIFIERS.size()]
		result.append(pick)
		remaining -= pick["cost"]

	return result
