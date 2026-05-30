# scripts/battle/states/player_turn_state.gd
class_name PlayerTurnState
extends BaseBattleState

var _selected:        BattleUnit        = null
var _pre_move_pos:    Vector2i          = Vector2i(-1, -1)
var _move_targets:    Array[Vector2i]   = []
var _atk_targets:     Array[BattleUnit] = []
var _ability_targets: Array[Vector2i]   = []

func enter(ctx: Node) -> void:
	# Auto-select the active unit so the player sees options immediately.
	_selected     = ctx.match_state.active_unit
	_pre_move_pos = Vector2i(-1, -1)
	_recompute(ctx)
	_refresh(ctx)

func exit(ctx: Node) -> void:
	_deselect(ctx)
	ctx.show_cancel_btn(false)

func handle_input(ctx: Node, event: InputEvent) -> void:
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tile_clicked(ctx, ctx.screen_to_grid(ctx.get_local_mouse_position()))

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_tile_clicked(ctx: Node, g: Vector2i) -> void:
	var ms: MatchState   = ctx.match_state
	var active: BattleUnit = ms.active_unit
	if not ms.board.is_in_bounds(g):
		return

	var clicked: BattleUnit = ms.board.get_unit_at(g)

	# Ability target
	if _selected != null and g in _ability_targets:
		ms.use_ability(_selected, g)
		_after_action(ctx)
		return

	# Attack target
	if _selected != null and clicked != null and clicked in _atk_targets:
		ms.attack(_selected, clicked)
		ctx.play_attack_animation(_selected, clicked)
		_after_action(ctx)
		return

	# Move target
	if _selected != null and g in _move_targets:
		_pre_move_pos = _selected.grid_pos
		ms.move_unit(_selected, g)
		AudioManager.play_sfx(&"move")
		_recompute(ctx)
		_refresh(ctx)
		ctx.show_cancel_btn(true)
		ctx.sync_sprites()
		_update_labels(ctx)
		return

	# (Re)select the active unit only
	if clicked != null and clicked == active:
		_selected = clicked
		_recompute(ctx)
		_refresh(ctx)
		return

	# Clicking elsewhere deselects
	_deselect(ctx)

func _after_action(ctx: Node) -> void:
	if ctx.match_state.winner() != -1:
		ctx.sync_sprites()
		ctx.change_state(WinLoseState.new())
		return
	ctx.show_cancel_btn(false)
	_pre_move_pos = Vector2i(-1, -1)
	# If both moved and acted, automatically end this unit's turn.
	if _selected != null and _selected.has_moved and _selected.has_acted:
		ctx.sync_sprites()
		ctx.advance_turn()
	else:
		_recompute(ctx)
		_refresh(ctx)
		ctx.sync_sprites()
		_update_labels(ctx)

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

func _deselect(ctx: Node) -> void:
	_selected = ctx.match_state.active_unit  # Stay on active unit
	_move_targets.clear()
	_atk_targets.clear()
	_ability_targets.clear()
	_refresh(ctx)

func _refresh(ctx: Node) -> void:
	ctx.highlight_tiles(_move_targets, _atk_targets, _ability_targets)
	_update_labels(ctx)

func _update_labels(ctx: Node) -> void:
	var active: BattleUnit = ctx.match_state.active_unit
	var info := ""
	if active != null:
		var ab := ""
		if active.data.ability != null:
			ab = "  [%s]" % AbilityData.Type.keys()[active.data.ability.type]
		info = "%s  HP:%d/%d  SPD:%d%s" % [
			active.data.display_name,
			active.current_hp, active.data.max_hp,
			active.data.speed, ab
		]
	ctx.set_labels("Your Turn", "", info)

## Called by MatchView when the Wait button is pressed.
func on_wait(ctx: Node) -> void:
	ctx.show_cancel_btn(false)
	_pre_move_pos = Vector2i(-1, -1)
	ctx.sync_sprites()
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
	else:
		ctx.advance_turn()

## Called by MatchView when the Cancel Move button is pressed.
func on_cancel_move(ctx: Node) -> void:
	if _selected == null or _pre_move_pos == Vector2i(-1, -1):
		return
	# Restore unit to its original position.
	ctx.match_state.board.relocate_unit(_selected, _pre_move_pos)
	_selected.grid_pos    = _pre_move_pos
	_selected.has_moved   = false
	_pre_move_pos         = Vector2i(-1, -1)
	ctx.show_cancel_btn(false)
	_recompute(ctx)
	_refresh(ctx)
	ctx.sync_sprites()
