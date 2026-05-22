class_name UpgradeCard
extends Resource

const ALL_CARDS: Array = [
	{"id": "scatter_shot",    "name": "Scatter Shot",    "desc": "Fires 3 projectiles in a spread cone",    "cursed": false, "tags": ["multi", "spread"]},
	{"id": "ricochet",        "name": "Ricochet",        "desc": "Bullets bounce off walls once",           "cursed": false, "tags": ["utility"]},
	{"id": "chain_lightning", "name": "Chain Lightning", "desc": "Every 5th shot chains to a nearby enemy", "cursed": false, "tags": ["chain", "multi"]},
	{"id": "overdrive",       "name": "Overdrive",       "desc": "+100% fire rate after room clear",        "cursed": false, "tags": ["fire_rate", "burst"]},
	{"id": "vampiric_round",  "name": "Vampiric Round",  "desc": "10% of damage dealt restores HP",         "cursed": false, "tags": ["sustain"]},
	{"id": "phantom_ammo",    "name": "Phantom Ammo",    "desc": "Projectiles pass through one enemy",      "cursed": false, "tags": ["pierce", "utility"]},
	{"id": "glass_cannon",    "name": "Glass Cannon",    "desc": "+80% damage, -30% max HP",                "cursed": true,  "tags": ["damage"]},
	{"id": "berserker",       "name": "Berserker",       "desc": "+100% fire rate, -20% max HP",            "cursed": true,  "tags": ["fire_rate"]},
]

static func draw_cards(owned_tags: Array, floor_number: int, rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = ALL_CARDS.duplicate()
	if floor_number < 3:
		pool = pool.filter(func(c: Dictionary) -> bool: return not c["cursed"])

	var weighted: Array = []
	for card: Dictionary in pool:
		var weight := 10
		for tag: String in card["tags"]:
			if tag in owned_tags:
				weight += 5
		for _i in weight:
			weighted.append(card)

	weighted.shuffle()

	var drawn: Array = []
	var seen: Array = []
	for card: Dictionary in weighted:
		if card["id"] not in seen:
			drawn.append(card)
			seen.append(card["id"])
		if drawn.size() >= count:
			break
	return drawn

static func apply_card(card_id: String, player: Node) -> void:
	match card_id:
		"scatter_shot":
			player.set_meta("scatter", true)
		"ricochet":
			pass  # Phase 3: requires wall physics layer
		"chain_lightning":
			player.set_meta("chain", true)
		"overdrive":
			player.fire_rate = maxf(player.fire_rate * 0.5, 0.1)
		"vampiric_round":
			player.set_meta("vampiric", true)
		"phantom_ammo":
			player.set_meta("phantom", true)
		"glass_cannon":
			player.damage_mult *= 1.8
			player.max_hp = int(player.max_hp * 0.7)
			player.hp = min(player.hp, player.max_hp)
		"berserker":
			player.fire_rate = maxf(player.fire_rate * 0.5, 0.1)
			player.max_hp = int(player.max_hp * 0.8)
			player.hp = min(player.hp, player.max_hp)
