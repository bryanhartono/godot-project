class_name MatchState
extends RefCounted

## The rules engine: holds the board and all units, and enforces movement,
## attacks, turn order, and win conditions.

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
	if attacker.has_acted:
		return false
	if not target in legal_targets(attacker):
		return false
	target.take_damage(attacker.data.atk)
	attacker.has_acted = true
	if not target.is_alive():
		board.remove_unit(target)  # removes from board; units[] keeps dead entries, filtered by is_alive()
	return true

func end_turn() -> void:
	current_team = 1 - current_team
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
