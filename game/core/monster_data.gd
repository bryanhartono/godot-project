class_name MonsterData
extends Resource

## Static stat block for one monster type. Runtime state lives in BattleUnit.

@export var id: StringName = &""
@export var display_name: String = ""
@export var cost: int = 1
@export var max_hp: int = 1
@export var atk: int = 1
@export var move_range: int = 1
@export var atk_range: int = 1
@export var ability: AbilityData = null
@export var sprite_row: int = 0

static func create(p_id: StringName, p_name: String, p_cost: int, p_hp: int, p_atk: int, p_move: int, p_range: int, p_ability: AbilityData = null, p_row: int = 0) -> MonsterData:
	var d := MonsterData.new()
	d.id = p_id
	d.display_name = p_name
	d.cost = p_cost
	d.max_hp = p_hp
	d.atk = p_atk
	d.move_range = p_move
	d.atk_range = p_range
	d.ability = p_ability
	d.sprite_row = p_row
	return d
