# scripts/battle/states/player_turn_state.gd
class_name PlayerTurnState
extends BaseBattleState

var _selected:        BattleUnit        = null
var _move_targets:    Array[Vector2i]   = []
var _atk_targets:     Array[BattleUnit] = []
var _ability_targets: Array[Vector2i]   = []

func enter(ctx: Node) -> void:
	_deselect(ctx)

func exit(ctx: Node) -> void:
	_deselect(ctx)

func handle_input(ctx: Node, event: InputEvent) -> void:
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tile_clicked(ctx, ctx.screen_to_grid(ctx.get_local_mouse_position()))

# ── Internal ──────────────────────────────────────────────────────────────────

func _on_tile_clicked(ctx: Node, g: Vector2i) -> void:
	var ms: MatchState = ctx.match_state
	if not ms.board.is_in_bounds(g):
		_deselect(ctx)
		return
	var clicked: BattleUnit = ms.board.get_unit_at(g)
	if _selected != null and g in _ability_targets:
		ms.use_ability(_selected, g)
		_after_action(ctx)
		return
	if _selected != null and clicked != null and clicked in _atk_targets:
		ms.attack(_selected, clicked)
		ctx.play_attack_animation(_selected)
		_after_action(ctx)
		return
	if _selected != null and g in _move_targets:
		ms.move_unit(_selected, g)
		_after_action(ctx)
		return
	if clicked != null and clicked.team == ms.current_team:
		_selected = clicked
		_recompute(ctx)
		_refresh(ctx)
		return
	_deselect(ctx)

func _after_action(ctx: Node) -> void:
	if ctx.match_state.winner() != -1:
		ctx.sync_sprites()
		ctx.change_state(WinLoseState.new())
		return
	if _selected != null and _selected.has_moved and _selected.has_acted:
		_deselect(ctx)
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
	_selected = null
	_move_targets.clear()
	_atk_targets.clear()
	_ability_targets.clear()
	_refresh(ctx)

func _refresh(ctx: Node) -> void:
	ctx.highlight_tiles(_move_targets, _atk_targets, _ability_targets)
	_update_labels(ctx)

func _update_labels(ctx: Node) -> void:
	var info := ""
	if _selected != null:
		var ab := ""
		if _selected.data.ability != null:
			ab = "  [%s]" % AbilityData.Type.keys()[_selected.data.ability.type]
		info = "%s  HP:%d/%d%s" % [_selected.data.display_name, _selected.current_hp, _selected.data.max_hp, ab]
	ctx.set_labels("Turn: PLAYER", "", info)

## Called by MatchView when the End Turn button is pressed.
func on_end_turn(ctx: Node) -> void:
	ctx.match_state.end_turn()
	_deselect(ctx)
	ctx.sync_sprites()
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
	else:
		ctx.change_state(AiTurnState.new(ctx.config.difficulty))
