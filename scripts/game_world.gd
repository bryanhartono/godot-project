extends Node2D

const ZOOM_LEVELS: Array[float] = [1.0, 2.0, 3.0, 4.0]

var _players: Array = []
var _active_dungeon: Node2D = null
var _zoom_index: int = 1  # default 2x
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.01
var _shake_timer: float = 0.0
var _fog_mat: ShaderMaterial = null
var _minimap: Control = null

@onready var entities: Node2D = $Entities
@onready var entities_spawner: MultiplayerSpawner = $Entities/EntitiesSpawner
@onready var card_draft_layer: CanvasLayer = $CardDraftLayer
@onready var card_row: HBoxContainer = $CardDraftLayer/Center/CardRow
@onready var camera: Camera2D = $Camera2D
@onready var _vignette: ColorRect = $VignetteLayer/Vignette

var _local_player: Node2D = null

func _ready() -> void:
	add_to_group("game_world")
	entities_spawner.spawn_path = NodePath("..")
	entities_spawner.add_spawnable_scene("res://scenes/dungeon_floor.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/boss.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/shop_npc.tscn")
	entities_spawner.add_spawnable_scene("res://scenes/loot_drop.tscn")

	RunManager.floor_changed.connect(_on_floor_changed)
	RunManager.run_ended.connect(_on_run_ended)
	card_draft_layer.visible = false
	_setup_fog()
	_setup_minimap()

	if NetworkManager.is_solo():
		_start_solo()
	elif multiplayer.is_server():
		_begin_run.rpc(randi())

func _process(delta: float) -> void:
	if is_instance_valid(_local_player):
		camera.global_position = _local_player.global_position
		if _fog_mat:
			var sp := get_viewport().get_canvas_transform() * _local_player.global_position
			_fog_mat.set_shader_parameter("player_screen_pos", sp)
		if _minimap:
			_minimap.set_player_pos(_local_player.global_position)
			var vp_sz := get_viewport().get_visible_rect().size
			_minimap.position = vp_sz - _minimap.size - Vector2(10.0, 10.0)
	_check_all_ghost()
	_tick_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_zoom_index = (_zoom_index + 1) % ZOOM_LEVELS.size()
		var z := ZOOM_LEVELS[_zoom_index]
		camera.zoom = Vector2(z, z)

# ── Player spawning ───────────────────────────────────────────────────────────

func _start_solo() -> void:
	var p = preload("res://scenes/player.tscn").instantiate()
	p.player_id = 1
	p.character_index = 0
	p.name = "Player_1"
	entities.add_child(p)
	_players = [p]
	_local_player = p
	RunManager.start_run()

@rpc("authority", "call_local", "reliable")
func _begin_run(seed_val: int) -> void:
	_spawn_multiplayer_players()
	RunManager.start_run(seed_val)

func _spawn_multiplayer_players() -> void:
	_players = []
	var peer_ids: Array = NetworkManager.players.keys()
	for i in peer_ids.size():
		var p = preload("res://scenes/player.tscn").instantiate()
		p.player_id = peer_ids[i]
		p.character_index = NetworkManager.get_character_selection(peer_ids[i])
		p.name = "Player_%d" % peer_ids[i]
		p.set_multiplayer_authority(peer_ids[i])
		entities.add_child(p)
		_players.append(p)
		if p.is_multiplayer_authority():
			_local_player = p

# ── Floor management ──────────────────────────────────────────────────────────

func _on_floor_changed(floor_number: int) -> void:
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return

	if is_instance_valid(_active_dungeon):
		_active_dungeon.queue_free()
	_active_dungeon = null

	var gen := DungeonGenerator.new()
	var dungeon_data := gen.generate(RunManager.run_seed + floor_number, floor_number)
	var tagged := gen.tag_rooms(floor_number)
	var map_size: Vector2i = dungeon_data.get("map_size", Vector2i(60, 44))

	var floor_node = preload("res://scenes/dungeon_floor.tscn").instantiate() as DungeonFloor
	floor_node.name = "DungeonFloor"
	entities.add_child(floor_node, true)
	_active_dungeon = floor_node
	floor_node.setup(tagged, dungeon_data["rooms"], dungeon_data["corridors"], floor_number, RunManager.rng, map_size)
	floor_node.all_combat_cleared.connect(_show_card_draft)
	if _minimap:
		floor_node.room_entered.connect(_minimap.mark_visited)
		_minimap.setup(tagged, map_size)
		_minimap.visible = true

	# Place players at the start of the first room
	var start: Vector2 = floor_node.get_start_position()
	_reposition_players(start)

func _reposition_players(center: Vector2) -> void:
	for i in _players.size():
		if is_instance_valid(_players[i]):
			if _players[i].is_multiplayer_authority() or NetworkManager.is_solo():
				_players[i].global_position = center + Vector2(i * 32.0, 0.0)

# ── Card draft ────────────────────────────────────────────────────────────────

func _show_card_draft() -> void:
	AudioManager.play("floor_clear")
	var owned_tags: Array[String] = []
	for p: Node in _players:
		if is_instance_valid(p):
			owned_tags.append_array(p.owned_upgrade_tags)
	var drawn := UpgradeCard.draw_cards(owned_tags, RunManager.current_floor, RunManager.rng)
	var card_ids: Array[String] = []
	for c: Dictionary in drawn:
		card_ids.append(c["id"])
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
	AudioManager.play("card_select")
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

func shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_duration = maxf(duration, 0.01)
	_shake_timer = maxf(_shake_timer, duration)

func on_player_damaged() -> void:
	_vignette.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.0, 0.35)

func _tick_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		return
	_shake_timer -= delta
	var t := maxf(_shake_timer, 0.0) / _shake_duration
	var s := _shake_intensity * t
	camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	if _shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_intensity = 0.0

func _check_all_ghost() -> void:
	if not RunManager._run_active or _players.is_empty():
		return
	if not NetworkManager.is_solo() and not multiplayer.is_server():
		return
	for p in _players:
		if is_instance_valid(p) and not p.is_ghost:
			return
	RunManager.end_run(false)

func _on_run_ended(won: bool) -> void:
	var summary = preload("res://scenes/run_summary.tscn").instantiate()
	add_child(summary)
	summary.setup(won, RunManager.current_floor, RunManager.kills)
	get_tree().paused = true

func _setup_fog() -> void:
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 3
	add_child(fog_layer)
	var fog_rect := ColorRect.new()
	fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = preload("res://shaders/fog_of_war.gdshader")
	fog_rect.material = _fog_mat
	fog_layer.add_child(fog_rect)

func _setup_minimap() -> void:
	var mm_layer := CanvasLayer.new()
	mm_layer.layer = 80
	add_child(mm_layer)
	_minimap = load("res://scripts/minimap.gd").new()
	_minimap.visible = false
	mm_layer.add_child(_minimap)
