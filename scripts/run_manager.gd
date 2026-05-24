extends Node

signal floor_changed(floor_number: int)
signal run_ended(won: bool)
signal combo_changed(count: int)

const BOSS_FLOOR_INTERVAL: int = 5
const BASE_BUDGET: int = 35
const DIFFICULTY_SCALAR: int = 10
const COMBO_WINDOW: float = 3.0
const COMBO_CAP: int = 20

var current_floor: int = 0
var run_seed: int = 0
var rng: RandomNumberGenerator
var combo_count: int = 0
var kills: int = 0
var _run_active: bool = false
var _combo_timer: float = 0.0

func _process(delta: float) -> void:
	if not _run_active or combo_count == 0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_set_combo(0)

func start_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed
	current_floor = 0
	combo_count = 0
	kills = 0
	_run_active = true
	advance_floor()

func advance_floor() -> void:
	current_floor += 1
	floor_changed.emit(current_floor)

func is_boss_floor() -> bool:
	return current_floor % BOSS_FLOOR_INTERVAL == 0

func end_run(won: bool) -> void:
	_run_active = false
	combo_count = 0
	run_ended.emit(won)

func get_floor_budget() -> int:
	var raw: int = BASE_BUDGET + current_floor * DIFFICULTY_SCALAR
	return int(raw * NetworkManager.get_player_count() * 0.75)

func get_boss_hp_multiplier() -> float:
	return 1.0 + (NetworkManager.get_player_count() - 1) * 0.6

func get_combo_multiplier() -> float:
	return 1.0 + minf(combo_count, COMBO_CAP) * 0.05

func on_enemy_killed() -> void:
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return
	kills += 1
	var new_count: int = combo_count + 1
	_set_combo(new_count)
	if not NetworkManager.is_solo():
		_sync_combo.rpc(new_count)

func on_player_hit() -> void:
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return
	_set_combo(0)
	if not NetworkManager.is_solo():
		_sync_combo.rpc(0)

func _set_combo(value: int) -> void:
	combo_count = value
	_combo_timer = COMBO_WINDOW if value > 0 else 0.0
	combo_changed.emit(value)

@rpc("authority", "call_local")
func _sync_combo(value: int) -> void:
	combo_count = value
	combo_changed.emit(value)
