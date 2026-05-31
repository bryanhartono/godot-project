# scripts/battle/states/player_turn_state.gd
class_name PlayerTurnState
extends BaseBattleState

var _selected:        BattleUnit        = null
var _move_targets:    Array[Vector2i]   = []
var _atk_targets:     Array[BattleUnit] = []
var _ability_targets: Array[Vector2i]   = []
var _pending_dest:    Vector2i          = Vector2i(-1, -1)
var _pending_path:    Array[Vector2i]   = []

func enter(ctx: Node) -> void:
	_selected     = ctx.match_state.active_unit
	_pending_dest = Vector2i(-1, -1)
	_pending_path.clear()
	ctx.hide_unit_popup()
	ctx.clear_move_preview()
	ctx.show_move_btn(false)
	_recompute(ctx)
	_refresh(ctx)

func exit(ctx: Node) -> void:
	ctx.clear_move_preview()
	ctx.show_move_btn(false)

func handle_input(ctx: Node, event: InputEvent) -> void:
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tile_clicked(ctx, ctx.screen_to_grid(ctx.get_local_mouse_position()))

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_tile_clicked(ctx: Node, g: Vector2i) -> void:
	var ms: MatchState     = ctx.match_state
	var active: BattleUnit = ms.active_unit
	if not ms.board.is_in_bounds(g):
		return

	var clicked: BattleUnit = ms.board.get_unit_at(g)

	# Ability target
	if _selected != null and g in _ability_targets:
		ctx.hide_unit_popup()
		ms.use_ability(_selected, g)
		_after_action(ctx)
		return

	# Attack target
	if _selected != null and clicked != null and clicked in _atk_targets:
		ctx.hide_unit_popup()
		ms.attack(_selected, clicked)
		ctx.play_attack_animation(_selected, clicked)
		_after_action(ctx)
		return

	# Move target — preview destination, wait for Move button confirmation
	if _selected != null and g in _move_targets:
		ctx.hide_unit_popup()
		_pending_dest = g
		_pending_path = _find_path(ms, _selected.grid_pos, g)
		var atk_tiles: Array[Vector2i] = ms.attack_tiles_from(_selected, g)
		ctx.show_move_preview(_selected, _pending_path, atk_tiles)
		ctx.show_move_btn(true)
		return

	# Tapping any unit shows the stat popup; also (re)selects if it's the active unit
	if clicked != null:
		ctx.show_unit_popup(clicked)
		if clicked == active:
			_selected = clicked
			_recompute(ctx)
			_refresh(ctx)
		return

	# Tapping empty non-move tile — clear preview, keep move tiles highlighted
	ctx.hide_unit_popup()
	ctx.clear_move_preview()
	ctx.show_move_btn(false)
	_pending_dest = Vector2i(-1, -1)
	_pending_path.clear()

func _after_action(ctx: Node) -> void:
	ctx.hide_unit_popup()
	ctx.clear_move_preview()
	ctx.show_move_btn(false)
	_pending_dest = Vector2i(-1, -1)
	_pending_path.clear()
	if ctx.match_state.winner() != -1:
		ctx.sync_sprites()
		ctx.change_state(WinLoseState.new())
		return
	if _selected != null and _selected.has_moved and _selected.has_acted:
		ctx.sync_sprites()
		ctx.advance_turn()
	else:
		_recompute(ctx)
		_refresh(ctx)
		ctx.sync_sprites()

func _recompute(ctx: Node) -> void:
	var ms: MatchState = ctx.match_state
	if _selected == null:
		_move_targets.clear()
		_atk_targets.clear()
		_ability_targets.clear()
		return
	_move_targets.clear()
	if not _selected.has_moved:
		_move_targets = ms.legal_moves(_selected)
	_atk_targets.clear()
	if not _selected.has_acted:
		_atk_targets = ms.legal_targets(_selected)
	_ability_targets = ms.legal_ability_targets(_selected)

func _refresh(ctx: Node) -> void:
	ctx.highlight_tiles(_move_targets, _atk_targets, _ability_targets)
	ctx.set_labels("Your Turn", "", "")

## Called by MatchView when the Move button is pressed.
func on_move_confirm(ctx: Node) -> void:
	if _selected == null or _pending_dest == Vector2i(-1, -1):
		return
	var ms: MatchState      = ctx.match_state
	var path: Array[Vector2i] = _pending_path.duplicate()
	ms.move_unit(_selected, _pending_dest)
	AudioManager.play_sfx(&"move")
	_pending_dest = Vector2i(-1, -1)
	_pending_path.clear()
	ctx.clear_move_preview()
	ctx.show_move_btn(false)
	ctx.walk_unit_to(_selected, path, func() -> void:
		_recompute(ctx)
		_refresh(ctx)
		ctx.sync_sprites()
	)

## Called by MatchView when the Wait button is pressed.
func on_wait(ctx: Node) -> void:
	ctx.hide_unit_popup()
	ctx.clear_move_preview()
	ctx.show_move_btn(false)
	_pending_dest = Vector2i(-1, -1)
	_pending_path.clear()
	ctx.sync_sprites()
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
	else:
		ctx.advance_turn()

## BFS from start to goal through passable tiles.
func _find_path(ms: MatchState, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var board := ms.board
	var open: Array[Vector2i] = [start]
	var came_from: Dictionary = { start: Vector2i(-999, -999) }
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while open.size() > 0:
		var cur: Vector2i = open.pop_front()
		if cur == goal:
			break
		for d: Vector2i in dirs:
			var nb: Vector2i = cur + d
			if came_from.has(nb):
				continue
			if not board.is_in_bounds(nb):
				continue
			# Intermediate tiles must be reachable move targets or the goal
			if nb != goal and nb not in _move_targets:
				continue
			# Cannot pass through units unless it is the goal tile
			if board.get_unit_at(nb) != null and nb != goal:
				continue
			came_from[nb] = cur
			open.append(nb)
	# Reconstruct path
	var path: Array[Vector2i] = []
	if not came_from.has(goal):
		return [start, goal]
	var cur: Vector2i = goal
	while cur != start:
		path.push_front(cur)
		cur = came_from[cur]
	path.push_front(start)
	return path
