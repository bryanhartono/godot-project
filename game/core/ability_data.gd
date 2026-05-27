class_name AbilityData
extends Resource

## Encodes one monster ability: type + a single integer parameter.
## Monsters with no ability have ability = null in their MonsterData.

enum Type {
	NONE,
	PASSIVE_POISON,      # On attack: target gains poison_stacks = param; ticks at start of its turn
	PASSIVE_TOUGH,       # On receive damage: reduce incoming damage by param (min 0)
	ACTIVE_BLINK,        # Instead of moving: teleport to any empty tile within Manhattan param
	ACTIVE_AOE_STRIKE,   # Instead of attacking: deal atk+param to primary target, param splash to adjacent enemies
}

@export var type: Type = Type.NONE
@export var param: int = 0

static func passive_poison(dmg: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.PASSIVE_POISON
	a.param = dmg
	return a

static func passive_tough(reduction: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.PASSIVE_TOUGH
	a.param = reduction
	return a

static func active_blink(range_val: int = 4) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.ACTIVE_BLINK
	a.param = range_val
	return a

static func active_aoe_strike(bonus_dmg: int = 1) -> AbilityData:
	var a := AbilityData.new()
	a.type = Type.ACTIVE_AOE_STRIKE
	a.param = bonus_dmg
	return a
