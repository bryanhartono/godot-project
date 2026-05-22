extends Node2D

signal room_cleared()

@export var room_type: String = "combat"

var _enemies_alive: int = 0
var _wave_started: bool = false

@onready var spawn_points: Node2D = $SpawnPoints
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready() -> void:
	spawner.spawn_path = NodePath(".")
	spawner.add_spawnable_scene("res://scenes/enemy.tscn")

func setup(type: String) -> void:
	room_type = type

func start_wave(enemy_data_list: Array) -> void:
	if _wave_started:
		return
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return
	_wave_started = true
	_enemies_alive = enemy_data_list.size()

	if _enemies_alive == 0:
		room_cleared.emit()
		return

	for i in enemy_data_list.size():
		var data: Dictionary = enemy_data_list[i]
		var enemy = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_hp = data.get("hp", 30)
		enemy.move_speed = data.get("speed", 60.0)
		enemy.budget_cost = data.get("cost", 3)
		enemy.elite_modifier = data.get("elite", "")
		var frames_path: String = data.get("frames", "")
		if not frames_path.is_empty():
			enemy.get_node("AnimatedSprite2D").sprite_frames = load(frames_path)
		var sp_count := spawn_points.get_child_count()
		if sp_count > 0:
			enemy.global_position = spawn_points.get_child(i % sp_count).global_position
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)

func _on_enemy_died(_enemy: Node) -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		room_cleared.emit()
