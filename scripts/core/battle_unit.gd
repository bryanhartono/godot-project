class_name BattleUnit
extends RefCounted

## A monster instance during a match. Holds mutable state; rules live in MatchState.

var data: MonsterData
var team: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var current_hp: int = 0
var has_moved: bool = false
var has_acted: bool = false
var poison_stacks: int = 0  # damage dealt at start of this unit's turn; does not reset
var ct: float = 0.0         # charge time for initiative; unit acts when ct >= 100

func _init(p_data: MonsterData = null, p_team: int = 0, p_pos: Vector2i = Vector2i.ZERO) -> void:
	data = p_data
	team = p_team
	grid_pos = p_pos
	if p_data != null:
		current_hp = p_data.max_hp

func is_alive() -> bool:
	return current_hp > 0

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func reset_turn() -> void:
	has_moved = false
	has_acted = false
