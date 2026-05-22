extends Node2D

func _ready() -> void:
	RunManager.run_ended.connect(_on_run_ended)
	if NetworkManager.is_solo():
		_start_solo()
	elif multiplayer.is_server():
		var seed_val := randi()
		_begin_run.rpc(seed_val)

func _start_solo() -> void:
	RunManager.start_run()
	var player = preload("res://scenes/player.tscn").instantiate()
	player.player_id = 1
	player.character_index = 0
	player.name = "Player_1"
	add_child(player)
	player.global_position = Vector2(200.0, 150.0)

@rpc("authority", "call_local", "reliable")
func _begin_run(seed_val: int) -> void:
	RunManager.start_run(seed_val)
	_spawn_multiplayer_players()

func _spawn_multiplayer_players() -> void:
	var peer_ids := NetworkManager.players.keys()
	for i in peer_ids.size():
		var player = preload("res://scenes/player.tscn").instantiate()
		player.player_id = peer_ids[i]
		player.character_index = i % 4
		player.name = "Player_%d" % peer_ids[i]
		player.set_multiplayer_authority(peer_ids[i])
		add_child(player)
		player.global_position = Vector2(100.0 + i * 40.0, 150.0)

func _on_run_ended(won: bool) -> void:
	var result := "Victory!" if won else "Defeated"
	print("Run over — ", result)
	# TODO Phase 4: transition to run summary screen
