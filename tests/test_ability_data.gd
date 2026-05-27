@tool
extends McpTestSuite

func suite_name() -> String:
	return "ability_data"

func test_passive_poison_factory() -> void:
	var a := AbilityData.passive_poison(2)
	assert_eq(a.type, AbilityData.Type.PASSIVE_POISON)
	assert_eq(a.param, 2)

func test_passive_poison_default() -> void:
	var a := AbilityData.passive_poison()
	assert_eq(a.param, 1)

func test_passive_tough_factory() -> void:
	var a := AbilityData.passive_tough(3)
	assert_eq(a.type, AbilityData.Type.PASSIVE_TOUGH)
	assert_eq(a.param, 3)

func test_passive_tough_default() -> void:
	var a := AbilityData.passive_tough()
	assert_eq(a.param, 1)

func test_active_blink_factory() -> void:
	var a := AbilityData.active_blink(6)
	assert_eq(a.type, AbilityData.Type.ACTIVE_BLINK)
	assert_eq(a.param, 6)

func test_active_blink_default() -> void:
	var a := AbilityData.active_blink()
	assert_eq(a.param, 4)

func test_active_aoe_strike_factory() -> void:
	var a := AbilityData.active_aoe_strike(2)
	assert_eq(a.type, AbilityData.Type.ACTIVE_AOE_STRIKE)
	assert_eq(a.param, 2)

func test_active_aoe_strike_default() -> void:
	var a := AbilityData.active_aoe_strike()
	assert_eq(a.param, 1)
