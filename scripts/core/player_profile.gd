# scripts/core/player_profile.gd
## Autoload: persistent player state. Registered as "PlayerProfile" in project settings.
## Saves immediately after any mutation to user://player_profile.json.
extends Node

const SAVE_PATH    := "user://player_profile.json"
const BUDGET       := 10
const STARTER_IDS: Array[StringName] = [&"soldier", &"orc", &"bat", &"ghost"]

const DAILY_REWARDS: Array = [
	{"gems": 10,  "monster": false},
	{"gems": 15,  "monster": false},
	{"gems": 20,  "monster": false},
	{"gems": 0,   "monster": true},
	{"gems": 25,  "monster": false},
	{"gems": 30,  "monster": false},
	{"gems": 50,  "monster": true},
]
const MISSED_DAY_COST    := 20
const LOOT_WIN_GEMS_MIN  := 15
const LOOT_WIN_GEMS_MAX  := 25
const LOOT_WIN_MONSTER   := 0.30
const LOOT_LOSS_GEMS_MIN := 5
const LOOT_LOSS_GEMS_MAX := 10
const LOOT_LOSS_MONSTER  := 0.10

var gems:  int   = 100
var owned: Array = []   # Array[OwnedMonster]
var squad: Array = []   # Array[MonsterData]

var calendar_day:    int    = 1
var last_claim_date: String = ""
var missed_days:     Array  = []   # Array[int]

## Set to false in unit tests to prevent disk writes.
var save_enabled := true
## Injected MonsterDB instance for @tool test context (autoloads are placeholders there).
## Leave null in production — falls back to the MonsterDB autoload.
var _db = null

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_load()
	else:
		_init_fresh()
		_save()

# ── Squad ─────────────────────────────────────────────────────────────────────

func set_squad(new_squad: Array[MonsterData]) -> void:
	var cost := 0
	for m in new_squad:
		cost += m.cost
	if cost > BUDGET:
		return
	squad = new_squad.duplicate()
	if save_enabled:
		_save()

func squad_cost() -> int:
	var total := 0
	for m in squad:
		total += m.cost
	return total

func add_owned(id: StringName) -> void:
	for o in owned:
		if o.data.id == id:
			o.duplicate_count += 1
			if save_enabled:
				_save()
			return
	var data := _get_monster(id)
	if data == null:
		return
	var om := OwnedMonster.new()
	om.data = data
	owned.append(om)
	if save_enabled:
		_save()

# ── Loot roll ─────────────────────────────────────────────────────────────────

## Call after each match. Returns {"gems": int, "monster": StringName}.
## monster is &"" when no monster dropped.
func roll_loot(won: bool) -> Dictionary:
	var gem_min := LOOT_WIN_GEMS_MIN  if won else LOOT_LOSS_GEMS_MIN
	var gem_max := LOOT_WIN_GEMS_MAX  if won else LOOT_LOSS_GEMS_MAX
	var chance  := LOOT_WIN_MONSTER   if won else LOOT_LOSS_MONSTER
	var earned  := randi_range(gem_min, gem_max)
	gems += earned
	var monster_id := &""
	if randf() < chance:
		var all := _all_monster_data()
		if not all.is_empty():
			var data: MonsterData = all[randi() % all.size()]
			monster_id = data.id
			add_owned(monster_id)
	if save_enabled:
		_save()
	return {"gems": earned, "monster": monster_id}

# ── Daily calendar ────────────────────────────────────────────────────────────

## Advances calendar past missed days. Call when the hub opens.
func tick_calendar() -> void:
	if last_claim_date == "":
		return
	var today := _today_string()
	if last_claim_date == today:
		return
	var days_passed := _days_between(last_claim_date, today)
	if days_passed <= 1:
		return
	for i in days_passed - 1:
		missed_days.append(calendar_day)
		calendar_day = (calendar_day % 7) + 1
	if save_enabled:
		_save()

## Returns {day, claimed, missed} without mutating state.
func daily_status() -> Dictionary:
	return {
		"day":     calendar_day,
		"claimed": last_claim_date == _today_string(),
		"missed":  missed_days.duplicate(),
	}

## Claims today's reward. Returns reward dict, or {} if already claimed today.
func claim_daily() -> Dictionary:
	if last_claim_date == _today_string():
		return {}
	var reward := DAILY_REWARDS[calendar_day - 1]
	var result := _apply_daily_reward(reward)
	last_claim_date = _today_string()
	calendar_day    = (calendar_day % 7) + 1
	if save_enabled:
		_save()
	return result

## Spends MISSED_DAY_COST gems to claim a missed day. Returns false if unable.
func buy_missed_day(day: int) -> bool:
	if not day in missed_days:
		return false
	if gems < MISSED_DAY_COST:
		return false
	gems -= MISSED_DAY_COST
	var reward := DAILY_REWARDS[day - 1]
	_apply_daily_reward(reward)
	missed_days.erase(day)
	if save_enabled:
		_save()
	return true

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_monster(id: StringName) -> MonsterData:
	return _db.get_monster(id) if _db != null else MonsterDB.get_monster(id)

func _all_monster_data() -> Array:
	return _db.all_monsters() if _db != null else MonsterDB.all_monsters()

func _apply_daily_reward(reward: Dictionary) -> Dictionary:
	var result := {"gems": 0, "monster": &""}
	var g: int = reward.get("gems", 0)
	gems += g
	result["gems"] = g
	if reward.get("monster", false):
		var all := _all_monster_data()
		if not all.is_empty():
			var data: MonsterData = all[randi() % all.size()]
			add_owned(data.id)
			result["monster"] = data.id
	return result

func _today_string() -> String:
	return Time.get_date_string_from_system()

func _days_between(from_date: String, to_date: String) -> int:
	var from_unix := Time.get_unix_time_from_datetime_dict(_parse_date(from_date))
	var to_unix   := Time.get_unix_time_from_datetime_dict(_parse_date(to_date))
	return int((to_unix - from_unix) / 86400.0)

func _parse_date(s: String) -> Dictionary:
	var p := s.split("-")
	return {"year": int(p[0]), "month": int(p[1]), "day": int(p[2]),
			"hour": 0, "minute": 0, "second": 0}

# ── Init ──────────────────────────────────────────────────────────────────────

func _init_fresh() -> void:
	gems            = 100
	calendar_day    = 1
	last_claim_date = ""
	missed_days     = []
	owned.clear()
	squad.clear()
	for id in STARTER_IDS:
		var data := _get_monster(id)
		if data == null:
			continue
		var om := OwnedMonster.new()
		om.data = data
		owned.append(om)
		squad.append(data)

# ── Persistence ───────────────────────────────────────────────────────────────

func _save() -> void:
	var owned_arr := []
	for o in owned:
		owned_arr.append({"id": str(o.data.id), "duplicates": o.duplicate_count})
	var squad_arr := []
	for m in squad:
		squad_arr.append(str(m.id))
	var payload := {
		"gems":            gems,
		"owned":           owned_arr,
		"squad":           squad_arr,
		"calendar_day":    calendar_day,
		"last_claim_date": last_claim_date,
		"missed_days":     missed_days.duplicate(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t"))

func _load() -> void:
	var f    := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	var d    := JSON.parse_string(text)
	if not d is Dictionary:
		_init_fresh()
		return
	gems            = d.get("gems",            100)
	calendar_day    = d.get("calendar_day",    1)
	last_claim_date = d.get("last_claim_date", "")
	missed_days     = d.get("missed_days",     [])
	owned.clear()
	for entry in d.get("owned", []):
		var data := _get_monster(StringName(entry["id"]))
		if data == null:
			continue
		var om := OwnedMonster.new()
		om.data            = data
		om.duplicate_count = entry.get("duplicates", 0)
		owned.append(om)
	squad.clear()
	for id_str in d.get("squad", []):
		var data := _get_monster(StringName(id_str))
		if data != null:
			squad.append(data)
