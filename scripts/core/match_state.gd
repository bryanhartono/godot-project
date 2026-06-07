class_name MatchState
extends RefCounted

## The rules engine: holds the board and all units, and enforces movement,
## attacks, turn order, win conditions, and ability activation.

## Preload so AbilityData.Type.* enum values resolve at compile time.
const _AbilityData = preload("res://scripts/core/ability_data.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var board: Board
var units: Array[BattleUnit] = []
## The unit whose turn it is right now. Null before initialize_initiative().
var active_unit: BattleUnit = null
## Convenience alias; kept for AI code that reads current_team.
var current_team: int = 0

func _init(p_board: Board = null) -> void:
	board = p_board if p_board != null else Board.new()

func add_unit(unit: BattleUnit, pos: Vector2i) -> void:
	board.place_unit(unit, pos)
	units.append(unit)

func units_for_team(team: int) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.team == team and u.is_alive():
			out.append(u)
	return out

# ── Initiative (CT / charge-time system) ─────────────────────────────────────

## Call once after all units are placed. Determines who acts first.
func initialize_initiative() -> void:
	for u: BattleUnit in units:
		u.ct = 0.0
	active_unit = null
	_find_next_unit()

## Call when the active unit has fully resolved their turn (acted or waited).
## Subtracts 100 CT from the unit that just acted, then finds the next one.
func advance_initiative() -> void:
	if active_unit != null:
		active_unit.ct = maxf(0.0, active_unit.ct - 100.0)
	_find_next_unit()

## Internal: tick CT for all alive units until the next one reaches 100, set active_unit.
func _find_next_unit() -> void:
	var alive: Array[BattleUnit] = []
	for u: BattleUnit in units:
		if u.is_alive():
			alive.append(u)
	if alive.is_empty():
		active_unit = null
		return

	# Minimum ticks until any unit hits 100 CT.
	var min_ticks: float = 1e9
	for u: BattleUnit in alive:
		var ticks: float = maxf(0.0, 100.0 - u.ct) / float(u.data.speed)
		if ticks < min_ticks:
			min_ticks = ticks

	for u: BattleUnit in alive:
		u.ct += min_ticks * float(u.data.speed)

	# Pick the unit with the highest CT; speed as tiebreak, then array order.
	var next: BattleUnit = alive[0]
	for u: BattleUnit in alive:
		if u.ct > next.ct or (u.ct == next.ct and u.data.speed > next.data.speed):
			next = u

	next.has_moved = false
	next.has_acted = false
	active_unit = next
	current_team = active_unit.team

	# Tick poison at start of this unit's turn.
	if active_unit.poison_stacks > 0:
		active_unit.take_damage(active_unit.poison_stacks)
		if not active_unit.is_alive():
			board.remove_unit(active_unit)
			_find_next_unit()
			return

## Peek at the next N units in initiative order without mutating state.
## Returns an array of BattleUnit in the order they will act.
func peek_initiative(n: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	if active_unit == null:
		return result

	var temp: Dictionary = {}  # BattleUnit -> float ct
	var alive: Array[BattleUnit] = []
	for u: BattleUnit in units:
		if u.is_alive():
			alive.append(u)
			temp[u] = u.ct

	var cur: BattleUnit = active_unit
	result.append(cur)

	for _i in range(n - 1):
		if alive.is_empty():
			break
		temp[cur] = maxf(0.0, temp.get(cur, 0.0) - 100.0)

		var min_ticks: float = 1e9
		for u: BattleUnit in alive:
			var ticks: float = maxf(0.0, 100.0 - temp.get(u, 0.0)) / float(u.data.speed)
			if ticks < min_ticks:
				min_ticks = ticks
		for u: BattleUnit in alive:
			temp[u] = temp.get(u, 0.0) + min_ticks * float(u.data.speed)

		var nxt: BattleUnit = alive[0]
		for u: BattleUnit in alive:
			var uct: float = temp.get(u, 0.0)
			var nct: float = temp.get(nxt, 0.0)
			if uct > nct or (uct == nct and u.data.speed > nxt.data.speed):
				nxt = u
		cur = nxt
		result.append(nxt)

	return result

# ── Movement & combat ─────────────────────────────────────────────────────────

## All empty, in-bounds tiles reachable within move_range via Dijkstra cost-BFS.
## Uphill 1 level costs 2; uphill 2+ levels is blocked for ground/water units.
## Flying units ignore elevation costs. Terrain passability is always enforced.
func legal_moves(unit: BattleUnit) -> Array[Vector2i]:
	if unit.has_moved:
		return []
	var mtype:  StringName      = unit.data.movement_type
	var budget: int             = unit.data.move_range
	var start:  Vector2i        = unit.grid_pos
	var cost_map: Dictionary    = { start: 0 }
	var queue: Array[Vector2i]  = [start]
	var result: Array[Vector2i] = []

	while queue.size() > 0:
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return cost_map[a] < cost_map[b]
		)
		var cur: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var nb: Vector2i = cur + d
			if not board.is_in_bounds(nb):
				continue
			if not board.is_passable(nb, mtype):
				continue
			if board.get_unit_at(nb) != null:
				continue
			var dh: int = board.elevation_at(nb) - board.elevation_at(cur)
			var step_cost: int = 1
			if mtype != &"flying":
				if dh >= 2:
					continue
				if dh == 1:
					step_cost = 2
			var new_cost: int = cost_map[cur] + step_cost
			if new_cost > budget:
				continue
			if cost_map.has(nb) and cost_map[nb] <= new_cost:
				continue
			cost_map[nb] = new_cost
			queue.append(nb)
			if nb not in result:
				result.append(nb)

	return result

func move_unit(unit: BattleUnit, pos: Vector2i) -> bool:
	if unit != active_unit:
		return false
	if unit.has_moved:
		return false
	if not pos in legal_moves(unit):
		return false
	board.relocate_unit(unit, pos)
	unit.has_moved = true
	return true

## All in-bounds tiles within attack range from an arbitrary position (for move preview).
func attack_tiles_from(unit: BattleUnit, from_pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = unit.data.atk_range
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if abs(dx) + abs(dy) > r or (dx == 0 and dy == 0):
				continue
			var g := from_pos + Vector2i(dx, dy)
			if board.is_in_bounds(g):
				out.append(g)
	return out

## Living enemy units within Manhattan attack range.
func legal_targets(unit: BattleUnit) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for other in units:
		if other.team == unit.team or not other.is_alive():
			continue
		var dist: int = abs(other.grid_pos.x - unit.grid_pos.x) + abs(other.grid_pos.y - unit.grid_pos.y)
		if dist <= unit.data.atk_range:
			out.append(other)
	return out

func attack(attacker: BattleUnit, target: BattleUnit) -> bool:
	if attacker != active_unit:
		return false
	if attacker.has_acted:
		return false
	if not target in legal_targets(attacker):
		return false
	var dmg: int = attacker.data.atk
	if target.data.ability != null and target.data.ability.type == _AbilityData.Type.PASSIVE_TOUGH:
		dmg = max(0, dmg - target.data.ability.param)
	target.take_damage(dmg)
	if attacker.data.ability != null and attacker.data.ability.type == _AbilityData.Type.PASSIVE_POISON:
		target.poison_stacks = max(target.poison_stacks, attacker.data.ability.param)
	attacker.has_acted = true
	if not target.is_alive():
		board.remove_unit(target)
	return true

## Returns the winning team (0 or 1), or -1 if the match is ongoing.
func winner() -> int:
	var alive0 := units_for_team(0).size()
	var alive1 := units_for_team(1).size()
	if alive0 == 0:
		return 1
	if alive1 == 0:
		return 0
	return -1

## Valid target positions for a unit's active ability (empty if passive or already used).
func legal_ability_targets(unit: BattleUnit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit.data.ability == null:
		return out
	match unit.data.ability.type:
		_AbilityData.Type.ACTIVE_BLINK:
			if unit.has_moved:
				return out
			for x in board.width:
				for y in board.height:
					var pos := Vector2i(x, y)
					if board.is_occupied(pos):
						continue
					var dist: int = abs(pos.x - unit.grid_pos.x) + abs(pos.y - unit.grid_pos.y)
					if dist > 0 and dist <= unit.data.ability.param:
						out.append(pos)
		_AbilityData.Type.ACTIVE_AOE_STRIKE:
			if unit.has_acted:
				return out
			for t in legal_targets(unit):
				out.append(t.grid_pos)
	return out

func use_ability(unit: BattleUnit, target_pos: Vector2i) -> bool:
	if unit != active_unit:
		return false
	if unit.data.ability == null:
		return false
	if not target_pos in legal_ability_targets(unit):
		return false
	match unit.data.ability.type:
		_AbilityData.Type.ACTIVE_BLINK:
			board.relocate_unit(unit, target_pos)
			unit.has_moved = true
		_AbilityData.Type.ACTIVE_AOE_STRIKE:
			var primary := board.get_unit_at(target_pos)
			primary.take_damage(unit.data.atk + unit.data.ability.param)
			if not primary.is_alive():
				board.remove_unit(primary)
			for d in DIRS:
				var adj := target_pos + d
				var splash := board.get_unit_at(adj)
				if splash != null and splash.team != unit.team and splash.is_alive():
					splash.take_damage(unit.data.ability.param)
					if not splash.is_alive():
						board.remove_unit(splash)
			unit.has_acted = true
	return true

## Returns a deep copy for AI simulation. Mutating the copy never affects self.
func duplicate() -> MatchState:
	var copy := MatchState.new(Board.new(board.width, board.height))
	copy.current_team = current_team
	var active_idx: int = units.find(active_unit)
	for i in range(units.size()):
		var u: BattleUnit = units[i]
		var u_copy := BattleUnit.new(u.data, u.team, u.grid_pos)
		u_copy.current_hp    = u.current_hp
		u_copy.has_moved     = u.has_moved
		u_copy.has_acted     = u.has_acted
		u_copy.poison_stacks = u.poison_stacks
		u_copy.ct            = u.ct
		copy.units.append(u_copy)
		copy.board.place_unit(u_copy, u_copy.grid_pos)
	if active_idx >= 0 and active_idx < copy.units.size():
		copy.active_unit = copy.units[active_idx]
	return copy

## Legacy no-op kept for AI simulation code that calls end_turn().
func end_turn() -> void:
	pass
