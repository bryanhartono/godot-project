## Heuristic AI for the enemy team. Pure RefCounted — no Node or scene dependency.
## Never mutates MatchState directly; all simulation uses duplicate().
class_name TacticsAI
extends RefCounted

class Action:
	const PASS    := 0
	const MOVE    := 1
	const ATTACK  := 2
	const ABILITY := 3

	var unit:          BattleUnit
	var move_to:       Vector2i
	var action_type:   int
	var action_target: Vector2i

	func _init(p_unit: BattleUnit, p_move: Vector2i, p_type: int, p_target: Vector2i = Vector2i(-1,-1)) -> void:
		unit          = p_unit
		move_to       = p_move
		action_type   = p_type
		action_target = p_target

## Entry point for the initiative-based system.
## Returns the best Action for state.active_unit.
func get_unit_action(state: MatchState, difficulty: int) -> Action:
	var unit: BattleUnit = state.active_unit
	if unit == null:
		return Action.new(unit, Vector2i(-1,-1), Action.PASS)
	var sim := state.duplicate()
	var su: BattleUnit = _mirror(sim, unit)
	if su == null:
		return Action.new(unit, unit.grid_pos, Action.PASS)
	sim.active_unit = su

	var best_score := -INF
	var best_opt: Array = [su.grid_pos, Action.PASS, Vector2i(-1, -1)]
	for opt in _unit_options(sim, su):
		var trial := sim.duplicate()
		var tu: BattleUnit = _mirror(trial, su)
		if tu == null:
			continue
		trial.active_unit = tu
		_apply_option(trial, tu, opt)
		var s: float = _score(trial, unit.team)
		# Hard difficulty: also penalise options that leave self exposed
		if difficulty >= 3:
			s -= _score(trial, 1 - unit.team) * 0.3
		if s > best_score:
			best_score = s
			best_opt   = opt
	return Action.new(unit, best_opt[0], best_opt[1], best_opt[2])

## Legacy batch entry point (kept so existing code compiles). Uses get_unit_action internally.
func get_actions(state: MatchState, ai_team: int, difficulty: int) -> Array:
	match difficulty:
		1: return _easy(state, ai_team)
		2: return _normal(state, ai_team)
		3: return _hard(state, ai_team)
	return _easy(state, ai_team)

# ── Scoring ────────────────────────────────────────────────────────────────────

## Higher score = better for ai_team.
func _score(state: MatchState, ai_team: int) -> float:
	var my_hp := 0.0
	var en_hp := 0.0
	for u in state.units:
		if not u.is_alive():
			continue
		if u.team == ai_team:
			my_hp += u.current_hp
		else:
			en_hp += u.current_hp
	return my_hp - en_hp

# ── Helpers ───────────────────────────────────────────────────────────────────

## Find the unit in `state` that corresponds to `original` (matched by grid_pos).
func _mirror(state: MatchState, original: BattleUnit) -> BattleUnit:
	return state.board.get_unit_at(original.grid_pos)

## Return all (move_pos, action_type, action_target) option arrays for one unit.
func _unit_options(state: MatchState, unit: BattleUnit) -> Array:
	state.active_unit = unit  # Allow this unit to act in simulation
	var opts := []
	var move_positions: Array[Vector2i] = [unit.grid_pos]
	if not unit.has_moved:
		move_positions.append_array(state.legal_moves(unit))

	for move_pos in move_positions:
		var sim := state.duplicate()
		var su := _mirror(sim, unit)
		if su == null:
			continue
		sim.active_unit = su
		if move_pos != su.grid_pos:
			sim.move_unit(su, move_pos)

		# Just move (no attack)
		opts.append([move_pos, Action.MOVE, Vector2i(-1, -1)])

		# Attack options
		if not su.has_acted:
			for target in sim.legal_targets(su):
				opts.append([move_pos, Action.ATTACK, target.grid_pos])
			# Ability options
			for ap in sim.legal_ability_targets(su):
				opts.append([move_pos, Action.ABILITY, ap])

	if opts.is_empty():
		opts.append([unit.grid_pos, Action.PASS, Vector2i(-1, -1)])
	return opts

## Apply one option to `unit` in `state`.
func _apply_option(state: MatchState, unit: BattleUnit, opt: Array) -> void:
	state.active_unit = unit  # Allow this unit to act in simulation
	var move_pos:      Vector2i = opt[0]
	var action_type:   int      = opt[1]
	var action_target: Vector2i = opt[2]
	if move_pos != unit.grid_pos:
		state.move_unit(unit, move_pos)
	match action_type:
		Action.ATTACK:
			var target := state.board.get_unit_at(action_target)
			if target:
				state.attack(unit, target)
		Action.ABILITY:
			state.use_ability(unit, action_target)

# ── Difficulty levels ─────────────────────────────────────────────────────────

## Easy: each unit independently picks the best immediate option.
## Works on a running simulation — original state is never touched.
func _easy(state: MatchState, ai_team: int) -> Array:
	var actions := []
	var sim := state.duplicate()  # single sim that accumulates choices
	var original_units := state.units_for_team(ai_team)

	for orig_unit in original_units:
		var su := _mirror(sim, orig_unit)
		if su == null or not su.is_alive():
			continue
		var best_score := -INF
		var best_opt: Array = [su.grid_pos, Action.PASS, Vector2i(-1, -1)]
		for opt in _unit_options(sim, su):
			var trial := sim.duplicate()
			var tu    := _mirror(trial, su)
			if tu == null:
				continue
			_apply_option(trial, tu, opt)
			var s := _score(trial, ai_team)
			if s > best_score:
				best_score = s
				best_opt   = opt
		# Record action using the original unit reference (for AiTurnState lookup)
		actions.append(Action.new(orig_unit, best_opt[0], best_opt[1], best_opt[2]))
		# Apply to sim so next unit sees updated board
		var su2 := _mirror(sim, su)
		if su2 != null:
			_apply_option(sim, su2, best_opt)
	return actions

## Normal: collect all team-action sequences, pick the highest-scoring.
func _normal(state: MatchState, ai_team: int) -> Array:
	var units := state.units_for_team(ai_team)
	var candidates: Array = []
	_collect_candidates(state, ai_team, units, 0, [], candidates)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	var best_seq: Array = candidates[0]["sequence"]

	var result := []
	var sim := state.duplicate()
	for i in range(units.size()):
		var orig_unit := units[i]
		var opt: Array = best_seq[i] if i < best_seq.size() else [orig_unit.grid_pos, Action.PASS, Vector2i(-1, -1)]
		var su := _mirror(sim, orig_unit)
		result.append(Action.new(orig_unit, opt[0], opt[1], opt[2]))
		if su != null:
			_apply_option(sim, su, opt)
	return result

## Hard: pick the Normal sequence that best survives the player's greedy response.
func _hard(state: MatchState, ai_team: int) -> Array:
	var player_team := 1 - ai_team
	var units := state.units_for_team(ai_team)

	var candidates: Array = []
	_collect_candidates(state, ai_team, units, 0, [], candidates)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var best_net := -INF
	var best_sequence: Array = []
	var top := mini(3, candidates.size())
	for i in range(top):
		var cand: Dictionary = candidates[i]
		var sim := state.duplicate()
		for j in range(units.size()):
			if j < cand["sequence"].size():
				var su := _mirror(sim, units[j])
				if su != null:
					_apply_option(sim, su, cand["sequence"][j])
		# Simulate player's greedy response and apply actions to sim
		sim.end_turn()
		var player_actions := _easy(sim, player_team)
		for pa in player_actions:
			var pu := sim.board.get_unit_at(pa.unit.grid_pos)
			if pu != null:
				_apply_option(sim, pu, [pa.move_to, pa.action_type, pa.action_target])
		var net := _score(sim, ai_team)
		if net > best_net:
			best_net = net
			best_sequence = cand["sequence"]

	var result := []
	var final_sim := state.duplicate()
	for i in range(units.size()):
		var orig_unit := units[i]
		var opt: Array = best_sequence[i] if i < best_sequence.size() else [orig_unit.grid_pos, Action.PASS, Vector2i(-1, -1)]
		var su := _mirror(final_sim, orig_unit)
		result.append(Action.new(orig_unit, opt[0], opt[1], opt[2]))
		if su != null:
			_apply_option(final_sim, su, opt)
	return result

## Collect all possible (unit sequence x option sequence) combinations into `out`.
func _collect_candidates(state: MatchState, ai_team: int, units: Array[BattleUnit],
		idx: int, current_seq: Array, out: Array) -> void:
	if idx >= units.size():
		out.append({"score": _score(state, ai_team), "sequence": current_seq.duplicate()})
		return
	var unit := units[idx]
	for opt in _unit_options(state, unit):
		var sim := state.duplicate()
		var su  := _mirror(sim, unit)
		if su == null:
			continue
		_apply_option(sim, su, opt)
		var new_seq := current_seq.duplicate()
		new_seq.append(opt)
		_collect_candidates(sim, ai_team, units, idx + 1, new_seq, out)
