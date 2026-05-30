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
@export var speed: int = 3       # 1 = slowest, 5 = fastest; drives CT initiative order
@export var sprite_row: int = 0
## Filename stem under res://resources/units/. Defaults to id if empty.
@export var sprite_file: StringName = &""

## Returns the stem used to load res://resources/units/<stem>.tres
func sprite_stem() -> StringName:
	return sprite_file if sprite_file != &"" else id

static func create(p_id: StringName, p_name: String, p_cost: int, p_hp: int, p_atk: int, p_move: int, p_range: int, p_ability: AbilityData = null, p_row: int = 0, p_sprite_file: StringName = &"", p_speed: int = 3) -> MonsterData:
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
	d.sprite_file = p_sprite_file
	d.speed = p_speed
	return d
