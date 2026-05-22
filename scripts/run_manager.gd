extends Node

signal floor_changed(floor_number: int)
signal run_ended(won: bool)

const BOSS_FLOOR_INTERVAL = 5
const BASE_BUDGET = 10
const DIFFICULTY_SCALAR = 3

var current_floor: int = 0
var run_seed: int = 0
var rng: RandomNumberGenerator
var _run_active: bool = false

func start_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	rng = RandomNumberGenerator.new()
	rng.seed = run_seed
	current_floor = 0
	_run_active = true
	advance_floor()

func advance_floor() -> void:
	current_floor += 1
	floor_changed.emit(current_floor)

func is_boss_floor() -> bool:
	return current_floor % BOSS_FLOOR_INTERVAL == 0

func end_run(won: bool) -> void:
	_run_active = false
	run_ended.emit(won)

func get_floor_budget() -> int:
	var raw = BASE_BUDGET + current_floor * DIFFICULTY_SCALAR
	var player_count = NetworkManager.get_player_count()
	return int(raw * player_count * 0.75)

func get_boss_hp_multiplier() -> float:
	var player_count = NetworkManager.get_player_count()
	return 1.0 + (player_count - 1) * 0.6
