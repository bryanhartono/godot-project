# scripts/battle/states/base_battle_state.gd
class_name BaseBattleState
extends RefCounted

## Abstract interface for all match states.
## `ctx` is the MatchView node — states call its public methods to read/update the board.
## Never store a permanent reference to ctx; only use it within enter/exit/handle_input.

func enter(_ctx: Node) -> void:
	pass

func exit(_ctx: Node) -> void:
	pass

func handle_input(_ctx: Node, _event: InputEvent) -> void:
	pass
