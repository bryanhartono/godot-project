class_name MatchState
extends RefCounted

## The rules engine: holds the board and all units, and enforces movement,
## attacks, turn order, win conditions, and ability activation.

## Preload so AbilityData.Type.* enum values resolve at compile time.
const _AbilityData = preload("res://scripts/core/ability_data.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var board: Board
var units: Array[BattleUnit] = []
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

## All empty, in-bounds tiles reachable within move_range via 4-directional steps.
func legal_moves(unit: BattleUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited := {unit.grid_pos: 0}
	var frontier: Array[Vector2i] = [unit.grid_pos]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var dist: int = visited[cur]
		if dist >= unit.data.move_range:
			continue
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if visited.has(nxt):
				continue
			if not board.is_in_bounds(nxt):
				continue
			if board.is_occupied(nxt):
				continue
			visited[nxt] = dist + 1
			result.append(nxt)
			frontier.append(nxt)
	return result

func move_unit(unit: BattleUnit, pos: Vector2i) -> bool:
	if unit.team != current_team:
		return false
	if unit.has_moved:
		return false
	if not pos in legal_moves(unit):
		return false
	board.relocate_unit(unit, pos)
	unit.has_moved = true
	return true

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
	if attacker.team != current_team:
		return false
	if attacker.has_acted:
		return false
	if not target in legal_targets(attacker):
		return false
	# Compute damage, reduced by PASSIVE_TOUGH on defender
	var dmg: int = attacker.data.atk
	if target.data.ability != null and target.data.ability.type == _AbilityData.Type.PASSIVE_TOUGH:
		dmg = max(0, dmg - target.data.ability.param)
	target.take_damage(dmg)
	# Apply PASSIVE_POISON from attacker
	if attacker.data.ability != null and attacker.data.ability.type == _AbilityData.Type.PASSIVE_POISON:
		target.poison_stacks = max(target.poison_stacks, attacker.data.ability.param)
	attacker.has_acted = true
	if not target.is_alive():
		board.remove_unit(target)
	return true

func end_turn() -> void:
	current_team = 1 - current_team
	# Tick poison on the newly-active team's units before they act
	for u in units_for_team(current_team):
		if u.poison_stacks > 0:
			u.take_damage(u.poison_stacks)
			if not u.is_alive():
				board.remove_unit(u)
	# Reset turn flags for surviving units
	for u in units_for_team(current_team):
		u.reset_turn()

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

## Returns a deep copy for AI simulation. Mutating the copy never affects self.
func duplicate() -> MatchState:
	var copy := MatchState.new(Board.new(board.width, board.height))
	copy.current_team = current_team
	for u in units:
		var u_copy := BattleUnit.new(u.data, u.team, u.grid_pos)
		u_copy.current_hp = u.current_hp
		u_copy.has_moved = u.has_moved
		u_copy.has_acted = u.has_acted
		u_copy.poison_stacks = u.poison_stacks
		copy.units.append(u_copy)
		copy.board.place_unit(u_copy, u_copy.grid_pos)
	return copy

## Execute a unit's active ability targeting target_pos. Returns false if invalid.
func use_ability(unit: BattleUnit, target_pos: Vector2i) -> bool:
	if unit.team != current_team:
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
