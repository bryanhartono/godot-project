# scripts/battle/states/ai_turn_state.gd
class_name AiTurnState
extends BaseBattleState

const AI_TEAM      := 1
const ACTION_DELAY := 0.35

var _difficulty: int

func _init(difficulty: int = 2) -> void:
	_difficulty = difficulty

func enter(ctx: Node) -> void:
	ctx.hide_unit_popup()
	var unit: BattleUnit = ctx.match_state.active_unit
	var name_str: String = unit.data.display_name if unit != null else "Enemy"
	ctx.set_labels("Enemy Turn", "", name_str)
	_execute(ctx)

func exit(_ctx: Node) -> void:
	pass

func handle_input(_ctx: Node, _event: InputEvent) -> void:
	pass

# ── Execution ─────────────────────────────────────────────────────────────────

func _execute(ctx: Node) -> void:
	var ms: MatchState = ctx.match_state
	var unit: BattleUnit = ms.active_unit
	if unit == null or unit.team != AI_TEAM:
		ctx.advance_turn()
		return

	var ai     := TacticsAI.new()
	var action: TacticsAI.Action = ai.get_unit_action(ms, _difficulty)

	var tween: Tween = ctx.create_tween()
	tween.tween_callback(_apply_action.bind(ctx, action)).set_delay(ACTION_DELAY)
	tween.tween_callback(_finish.bind(ctx)).set_delay(ACTION_DELAY)

func _apply_action(ctx: Node, action: TacticsAI.Action) -> void:
	var ms: MatchState   = ctx.match_state
	var unit: BattleUnit = ms.active_unit
	if unit == null or unit.team != AI_TEAM:
		return

	if action.move_to != Vector2i(-1, -1) and action.move_to != unit.grid_pos:
		ms.move_unit(unit, action.move_to)

	match action.action_type:
		TacticsAI.Action.ATTACK:
			var target := ms.board.get_unit_at(action.action_target)
			if target:
				ms.attack(unit, target)
				ctx.play_attack_animation(unit, target)
		TacticsAI.Action.ABILITY:
			ms.use_ability(unit, action.action_target)

	ctx.sync_sprites()

func _finish(ctx: Node) -> void:
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
		return
	ctx.sync_sprites()
	ctx.advance_turn()
