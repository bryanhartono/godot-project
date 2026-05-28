# scripts/battle/states/base_battle_state.gd
class_name BaseBattleState
extends RefCounted

## Abstract interface for all match states.
## `ctx` is the MatchView node — states call its public methods to read/update the board.
## Never store a permanent reference to ctx; only use it within enter/exit/handle_input.

func enter(ctx: Node) -> void:
	pass

func exit(ctx: Node) -> void:
	pass

func handle_input(ctx: Node, event: InputEvent) -> void:
	pass
