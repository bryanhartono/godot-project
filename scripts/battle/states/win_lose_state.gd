# scripts/battle/states/win_lose_state.gd
class_name WinLoseState
extends BaseBattleState

func enter(ctx: Node) -> void:
	var winner: int = ctx.match_state.winner()
	ctx.show_win_lose_overlay(winner)
	# Phase 5 hook: ctx.ads_manager.show_interstitial(_on_ad_closed.bind(ctx))
	# For now, overlay is shown immediately.

func exit(ctx: Node) -> void:
	ctx.hide_win_lose_overlay()

func handle_input(_ctx: Node, _event: InputEvent) -> void:
	pass  # Buttons handle their own signals; no tile input needed here.
