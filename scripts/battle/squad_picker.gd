## Generates random budget-legal squads from MonsterDB.
## Uses only static methods — no instance needed.

static func random_squad(budget: int, pool: Array[MonsterData] = []) -> Array[MonsterData]:
	var p: Array[MonsterData] = pool if not pool.is_empty() else MonsterDB.all_monsters()
	p = p.duplicate()
	p.shuffle()
	var squad: Array[MonsterData] = []
	var remaining := budget
	for m in p:
		if m.cost <= remaining:
			squad.append(m)
			remaining -= m.cost
		if remaining <= 0:
			break
	return squad
