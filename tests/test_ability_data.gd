@tool
extends McpTestSuite

func suite_name() -> String:
	return "ability_data"

func test_passive_poison_factory() -> void:
	var a := AbilityData.passive_poison(2)
	assert_eq(a.type, AbilityData.Type.PASSIVE_POISON)
	assert_eq(a.param, 2)

func test_passive_tough_factory() -> void:
	var a := AbilityData.passive_tough(1)
	assert_eq(a.type, AbilityData.Type.PASSIVE_TOUGH)
	assert_eq(a.param, 1)

func test_active_blink_factory() -> void:
	var a := AbilityData.active_blink(4)
	assert_eq(a.type, AbilityData.Type.ACTIVE_BLINK)
	assert_eq(a.param, 4)

func test_active_aoe_strike_factory() -> void:
	var a := AbilityData.active_aoe_strike(1)
	assert_eq(a.type, AbilityData.Type.ACTIVE_AOE_STRIKE)
	assert_eq(a.param, 1)
