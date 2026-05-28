# scripts/battle/states/ai_turn_state.gd
class_name AiTurnState
extends BaseBattleState

const AI_TEAM       := 1
const ACTION_DELAY  := 0.4   # seconds between AI actions

var _difficulty: int
var _actions:    Array = []

func _init(difficulty: int = 2) -> void:
	_difficulty = difficulty

func enter(ctx: Node) -> void:
	ctx.set_labels("Turn: AI", "", "")
	var ai := TacticsAI.new()
	_actions = ai.get_actions(ctx.match_state, AI_TEAM, _difficulty)
	_start_processing(ctx)

func exit(ctx: Node) -> void:
	pass

func handle_input(_ctx: Node, _event: InputEvent) -> void:
	pass  # Player cannot interact during AI turn

# ── Action execution via Tween ────────────────────────────────────────────────

func _start_processing(ctx: Node) -> void:
	if _actions.is_empty():
		_finish_turn(ctx)
		return
	var tween: Tween = ctx.create_tween()
	for i in range(_actions.size()):
		tween.tween_callback(_apply_next_action.bind(ctx, i)).set_delay(ACTION_DELAY)
	tween.tween_callback(_finish_turn.bind(ctx)).set_delay(ACTION_DELAY)

func _apply_next_action(ctx: Node, idx: int) -> void:
	if idx >= _actions.size():
		return
	var action: TacticsAI.Action = _actions[idx]
	var ms: MatchState = ctx.match_state
	var real_unit := ms.board.get_unit_at(action.unit.grid_pos)
	if real_unit == null or real_unit.team != AI_TEAM:
		return
	if action.move_to != Vector2i(-1, -1) and action.move_to != real_unit.grid_pos:
		ms.move_unit(real_unit, action.move_to)
	match action.action_type:
		TacticsAI.Action.ATTACK:
			var target := ms.board.get_unit_at(action.action_target)
			if target:
				ms.attack(real_unit, target)
		TacticsAI.Action.ABILITY:
			ms.use_ability(real_unit, action.action_target)
	ctx.sync_sprites()

func _finish_turn(ctx: Node) -> void:
	if ctx.match_state.winner() != -1:
		ctx.change_state(WinLoseState.new())
		return
	ctx.match_state.end_turn()
	ctx.sync_sprites()
	ctx.change_state(PlayerTurnState.new())
