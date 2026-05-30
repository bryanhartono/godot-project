# scripts/battle/ranked_pool.gd
class_name RankedPool
extends RefCounted

## Hardcoded snapshot squads for the serverless ranked ladder.
## Squads are grouped by trophy bracket; pick_opponent() returns one at random
## from the bracket matching the player's current trophies.

# Each bracket is an Array of squad definitions (Array[StringName]).
# Trophies: 0-29 = Bronze, 30-59 = Silver, 60-99 = Gold, 100+ = Diamond.
const _BRACKETS: Array = [
	# Bronze 0-29
	[
		[&"soldier", &"orc", &"bat", &"goblin_grunt", &"goblin_grunt"],
		[&"soldier", &"soldier", &"ghost", &"goblin_grunt", &"goblin_grunt"],
		[&"goblin", &"orc", &"goblin_grunt", &"goblin_grunt", &"goblin_grunt"],
	],
	# Silver 30-59
	[
		[&"goblin", &"goblin_slinger", &"archer", &"goblin_grunt", &"goblin_grunt", &"goblin_grunt"],
		[&"knight", &"slime", &"soldier", &"goblin_grunt", &"goblin_grunt"],
		[&"undead_soldier", &"undead_soldier", &"skeleton_archer", &"goblin_grunt", &"goblin_grunt"],
	],
	# Gold 60-99
	[
		[&"wraith", &"spider", &"bat", &"soldier"],
		[&"assassin", &"skeleton_archer", &"goblin_slinger", &"goblin_grunt", &"goblin_grunt"],
		[&"imp", &"wraith", &"slime", &"goblin_grunt"],
	],
	# Diamond 100+
	[
		[&"knight", &"wraith", &"imp", &"goblin_grunt"],
		[&"crab", &"imp", &"assassin", &"goblin_grunt"],
		[&"assassin", &"wraith", &"spider", &"bat", &"goblin_grunt"],
	],
]

static func pick_opponent(trophies: int) -> Array[MonsterData]:
	var bracket_idx: int
	if trophies < 30:
		bracket_idx = 0
	elif trophies < 60:
		bracket_idx = 1
	elif trophies < 100:
		bracket_idx = 2
	else:
		bracket_idx = 3

	var bracket: Array = _BRACKETS[bracket_idx]
	var ids: Array = bracket[randi() % bracket.size()]
	var squad: Array[MonsterData] = []
	for id: StringName in ids:
		var data: MonsterData = MonsterDB.get_monster(id)
		if data != null:
			squad.append(data)
	return squad
