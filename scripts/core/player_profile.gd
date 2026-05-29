# scripts/core/player_profile.gd
## Autoload: persistent player state. Registered as "PlayerProfile" in project settings.
## Saves immediately after any mutation to user://player_profile.json.
extends Node

const SAVE_PATH    := "user://player_profile.json"
const BUDGET       := 10
const STARTER_IDS: Array[StringName] = [&"soldier", &"orc", &"bat", &"ghost"]

var gems:  int   = 100
var owned: Array = []   # Array[OwnedMonster]
var squad: Array = []   # Array[MonsterData]

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

func set_squad(new_squad: Array[MonsterData]) -> void:
	var cost := 0
	for m in new_squad:
		cost += m.cost
	if cost > BUDGET:
		return
	squad = new_squad.duplicate()
	if save_enabled:
		_save()

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

func squad_cost() -> int:
	var total := 0
	for m in squad:
		total += m.cost
	return total

func _get_monster(id: StringName) -> MonsterData:
	return _db.get_monster(id) if _db != null else MonsterDB.get_monster(id)

# ── Init ──────────────────────────────────────────────────────────────────────

func _init_fresh() -> void:
	gems = 100
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
	var payload := {"gems": gems, "owned": owned_arr, "squad": squad_arr}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t"))

func _load() -> void:
	var f    := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	var d    := JSON.parse_string(text)
	if not d is Dictionary:
		_init_fresh()
		return
	gems = d.get("gems", 100)
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
