@tool
extends McpTestSuite

const _MonsterDbScript = preload("res://scripts/core/monster_db.gd")

func suite_name() -> String:
	return "player_profile"

func test_placeholder() -> void:
	assert_true(true)

func test_starter_ids_valid() -> void:
	var db = _MonsterDbScript.new()
	db._ready()
	assert_true(db.get_monster(&"soldier") != null)
	assert_true(db.get_monster(&"orc") != null)
	assert_true(db.get_monster(&"bat") != null)
	assert_true(db.get_monster(&"ghost") != null)

func test_starter_squad_cost_within_budget() -> void:
	var db = _MonsterDbScript.new()
	db._ready()
	var total := 0
	total += db.get_monster(&"soldier").cost
	total += db.get_monster(&"orc").cost
	total += db.get_monster(&"bat").cost
	total += db.get_monster(&"ghost").cost
	assert_true(total <= 10)

func test_daily_rewards_has_seven_entries() -> void:
	assert_true(PlayerProfile.DAILY_REWARDS.size() == 7)

func test_missed_day_cost_is_twenty() -> void:
	assert_true(PlayerProfile.MISSED_DAY_COST == 20)

func test_loot_win_range_is_valid() -> void:
	assert_true(PlayerProfile.LOOT_WIN_GEMS_MIN > 0)
	assert_true(PlayerProfile.LOOT_WIN_GEMS_MAX >= PlayerProfile.LOOT_WIN_GEMS_MIN)

func test_loot_loss_range_is_valid() -> void:
	assert_true(PlayerProfile.LOOT_LOSS_GEMS_MIN > 0)
	assert_true(PlayerProfile.LOOT_LOSS_GEMS_MAX >= PlayerProfile.LOOT_LOSS_GEMS_MIN)

func test_loot_win_more_than_loss() -> void:
	assert_true(PlayerProfile.LOOT_WIN_GEMS_MIN > PlayerProfile.LOOT_LOSS_GEMS_MAX)

func test_daily_reward_day4_has_monster() -> void:
	var day4: Dictionary = PlayerProfile.DAILY_REWARDS[3]
	assert_true(day4.get("monster", false) == true)

func test_daily_reward_day7_has_monster() -> void:
	var day7: Dictionary = PlayerProfile.DAILY_REWARDS[6]
	assert_true(day7.get("monster", false) == true)

func test_daily_reward_day1_gems_only() -> void:
	var day1: Dictionary = PlayerProfile.DAILY_REWARDS[0]
	assert_true(day1.get("gems", 0) > 0)
	assert_true(day1.get("monster", false) == false)
