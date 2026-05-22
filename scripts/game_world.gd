extends Node2D

const ROOM_SPAWN_POS := Vector2(320.0, 240.0)
const PLAYER_START := Vector2(240.0, 240.0)

var _tagged_rooms: Array = []
var _room_index: int = 0
var _active_room: Node2D = null
var _players: Array = []
var _transitioning: bool = false

@onready var entities: Node2D = $Entities
@onready var entities_spawner: MultiplayerSpawner = $Entities/EntitiesSpawner
@onready var card_draft_layer: CanvasLayer = $CardDraftLayer
@onready var card_row: HBoxContainer = $CardDraftLayer/Center/CardRow

func _ready() -> void:
	entities_spawner.spawn_path = NodePath("..")
	entities_spawner.add_spawnable_scene("res://scenes/room.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/boss.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/shop_npc.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/loot_drop.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/trap_room.tscn")

	RunManager.floor_changed.connect(_on_floor_changed)
	RunManager.run_ended.connect(_on_run_ended)
	card_draft_layer.visible = false

	if NetworkManager.is_solo():
		_start_solo()
	elif multiplayer.is_server():
		_begin_run.rpc(randi())

func _start_solo() -> void:
	RunManager.start_run()
	var p = preload("res://scenes/player.tscn").instantiate()
	p.player_id = 1
	p.character_index = 0
	p.name = "Player_1"
	entities.add_child(p)
	p.global_position = PLAYER_START
	_players = [p]

@rpc("authority", "call_local", "reliable")
func _begin_run(seed_val: int) -> void:
	RunManager.start_run(seed_val)
	_spawn_multiplayer_players()

func _spawn_multiplayer_players() -> void:
	_players = []
	var peer_ids := NetworkManager.players.keys()
	for i in peer_ids.size():
		var p = preload("res://scenes/player.tscn").instantiate()
		p.player_id = peer_ids[i]
		p.character_index = NetworkManager.get_character_selection(peer_ids[i])
		p.name = "Player_%d" % peer_ids[i]
		p.set_multiplayer_authority(peer_ids[i])
		entities.add_child(p)
		p.global_position = PLAYER_START + Vector2(i * 40.0, 0.0)
		_players.append(p)

# ---- Floor / room logic (server-only, clients receive via RPCs) ----

func _on_floor_changed(floor_number: int) -> void:
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return
	var gen := DungeonGenerator.new()
	gen.generate(RunManager.run_seed + floor_number)
	_tagged_rooms = gen.tag_rooms(floor_number)
	_room_index = 0
	_transitioning = false
	_load_next_room()

func _load_next_room() -> void:
	if _active_room and is_instance_valid(_active_room):
		_active_room.queue_free()
	_active_room = null

	if _room_index >= _tagged_rooms.size():
		_show_card_draft()
		return

	var rd: Dictionary = _tagged_rooms[_room_index]
	_room_index += 1
	_reposition_players()

	match rd["type"]:
		"combat":     _enter_combat()
		"trap":       _enter_trap(rd)
		"shop":       _enter_shop()
		"treasure":   _enter_treasure()
		"boss_entry": _enter_boss()
		_:            _enter_combat()

func _reposition_players() -> void:
	var positions: Array = []
	for i in _players.size():
		positions.append(PLAYER_START + Vector2(i * 40.0, 0.0))
	_reposition_all.rpc(positions)

@rpc("authority", "call_local", "reliable")
func _reposition_all(positions: Array) -> void:
	for i in _players.size():
		if i < positions.size() and is_instance_valid(_players[i]):
			if _players[i].is_multiplayer_authority():
				_players[i].global_position = positions[i]

func _enter_combat() -> void:
	var room = preload("res://scenes/room.tscn").instantiate()
	room.position = Vector2.ZERO
	room.room_cleared.connect(_on_combat_cleared)
	entities.add_child(room)
	_active_room = room
	var composer := WaveComposer.new()
	var enemies := composer.compose(
		RunManager.current_floor, RunManager.get_floor_budget(), RunManager.rng
	)
	room.start_wave(enemies)

func _enter_trap(rd: Dictionary) -> void:
	var trap = preload("res://scenes/trap_room.tscn").instantiate()
	trap.position = Vector2.ZERO
	entities.add_child(trap)
	_active_room = trap
	trap.generate_traps(rd["rect"], RunManager.rng)
	get_tree().create_timer(8.0).timeout.connect(_on_room_cleared)

func _enter_shop() -> void:
	var npc = preload("res://scenes/shop_npc.tscn").instantiate()
	npc.position = ROOM_SPAWN_POS
	npc.shop_closed.connect(_on_room_cleared)
	entities.add_child(npc)
	_active_room = npc
	npc.open_shop()

func _enter_treasure() -> void:
	var loot = preload("res://scenes/loot_drop.tscn").instantiate()
	loot.global_position = ROOM_SPAWN_POS
	loot.picked_up.connect(_on_room_cleared)
	entities.add_child(loot)
	_active_room = loot
	get_tree().create_timer(15.0).timeout.connect(_on_room_cleared)

func _enter_boss() -> void:
	var boss = preload("res://scenes/boss.tscn").instantiate()
	boss.position = ROOM_SPAWN_POS
	boss.died.connect(_on_boss_died)
	entities.add_child(boss)
	_active_room = boss

func _on_combat_cleared() -> void:
	if _transitioning:
		return
	_transitioning = true
	var loot = preload("res://scenes/loot_drop.tscn").instantiate()
	loot.global_position = ROOM_SPAWN_POS
	entities.add_child(loot)
	await get_tree().create_timer(1.0).timeout
	_transitioning = false
	_load_next_room()

func _on_room_cleared() -> void:
	if _transitioning:
		return
	_transitioning = true
	await get_tree().create_timer(0.3).timeout
	_transitioning = false
	_load_next_room()

func _on_boss_died() -> void:
	RunManager.end_run(true)

# ---- Card draft (server draws pool, broadcasts to all peers) ----

func _show_card_draft() -> void:
	var owned_tags: Array = []
	for p in _players:
		if is_instance_valid(p):
			owned_tags.append_array(p.owned_upgrade_tags)
	var drawn := UpgradeCard.draw_cards(owned_tags, RunManager.current_floor, RunManager.rng)
	var card_ids: Array = drawn.map(func(c: Dictionary) -> String: return c["id"])
	_present_card_draft.rpc(card_ids)

@rpc("authority", "call_local", "reliable")
func _present_card_draft(card_ids: Array) -> void:
	get_tree().paused = true
	card_draft_layer.visible = true
	for c in card_row.get_children():
		c.queue_free()
	for card_id: String in card_ids:
		var matches := UpgradeCard.ALL_CARDS.filter(
			func(c: Dictionary) -> bool: return c["id"] == card_id
		)
		if matches.is_empty():
			continue
		var cd: Dictionary = matches[0]
		var card_ui = preload("res://scenes/upgrade_card.tscn").instantiate()
		card_ui.get_node("VBox/CardName").text = cd["name"]
		card_ui.get_node("VBox/CardDesc").text = cd["desc"]
		var btn: Button = card_ui.get_node("VBox/SelectButton")
		if NetworkManager.is_solo() or multiplayer.is_server():
			btn.pressed.connect(_on_card_selected.bind(card_id))
		else:
			btn.text = "Host picks..."
			btn.disabled = true
		card_row.add_child(card_ui)

func _on_card_selected(card_id: String) -> void:
	_apply_card_selection.rpc(card_id)

@rpc("authority", "call_local", "reliable")
func _apply_card_selection(card_id: String) -> void:
	card_draft_layer.visible = false
	get_tree().paused = false
	var matches := UpgradeCard.ALL_CARDS.filter(
		func(c: Dictionary) -> bool: return c["id"] == card_id
	)
	var tags: Array = matches[0].get("tags", []) if not matches.is_empty() else []
	for p in _players:
		if is_instance_valid(p) and p.is_multiplayer_authority():
			UpgradeCard.apply_card(card_id, p)
			p.owned_upgrade_tags.append_array(tags)
	RunManager.advance_floor()

func _on_run_ended(won: bool) -> void:
	print("Run over — ", "Victory!" if won else "Defeated")
	# TODO Phase 4: run summary screen
