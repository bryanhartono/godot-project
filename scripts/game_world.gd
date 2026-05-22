extends Node2D

const ROOM_SPAWN_POS := Vector2(320.0, 240.0)
const PLAYER_START := Vector2(240.0, 240.0)

var _tagged_rooms: Array = []
var _room_index: int = 0
var _active_room: Node2D = null
var _players: Array = []
var _transitioning: bool = false

@onready var entities: Node2D = $Entities
@onready var card_draft_layer: CanvasLayer = $CardDraftLayer
@onready var card_row: HBoxContainer = $CardDraftLayer/Center/CardRow

func _ready() -> void:
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
		p.character_index = i % 4
		p.name = "Player_%d" % peer_ids[i]
		p.set_multiplayer_authority(peer_ids[i])
		entities.add_child(p)
		p.global_position = PLAYER_START + Vector2(i * 40.0, 0.0)
		_players.append(p)

func _on_floor_changed(floor_number: int) -> void:
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
	for i in _players.size():
		if is_instance_valid(_players[i]):
			_players[i].global_position = PLAYER_START + Vector2(i * 40.0, 0.0)

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

func _show_card_draft() -> void:
	get_tree().paused = true
	card_draft_layer.visible = true
	for c in card_row.get_children():
		c.queue_free()
	var owned_tags: Array = []
	for p in _players:
		if is_instance_valid(p):
			owned_tags.append_array(p.owned_upgrade_tags)
	var drawn := UpgradeCard.draw_cards(owned_tags, RunManager.current_floor, RunManager.rng)
	for card_data: Dictionary in drawn:
		var card_ui = preload("res://scenes/upgrade_card.tscn").instantiate()
		card_ui.get_node("VBox/CardName").text = card_data["name"]
		card_ui.get_node("VBox/CardDesc").text = card_data["desc"]
		card_ui.get_node("VBox/SelectButton").pressed.connect(_on_card_selected.bind(card_data))
		card_row.add_child(card_ui)

func _on_card_selected(card_data: Dictionary) -> void:
	card_draft_layer.visible = false
	get_tree().paused = false
	for p in _players:
		if is_instance_valid(p):
			UpgradeCard.apply_card(card_data["id"], p)
			p.owned_upgrade_tags.append_array(card_data.get("tags", []))
	RunManager.advance_floor()

func _on_run_ended(won: bool) -> void:
	print("Run over — ", "Victory!" if won else "Defeated")
	# TODO Phase 4: run summary screen
