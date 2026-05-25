class_name DungeonFloor
extends Node2D

signal all_combat_cleared
signal room_entered(room_index: int)

var _map_size: Vector2i = Vector2i(60, 44)

var _tagged_rooms: Array[Dictionary] = []
var _floor_number: int = 0
var _rng: RandomNumberGenerator
var _combat_total: int = 0
var _combat_cleared: int = 0

@onready var tilemap: TileMapLayer = $TileMapLayer


func setup(tagged_rooms: Array[Dictionary], rooms: Array[Rect2i], corridors: Array[Rect2i], floor_number: int, rng: RandomNumberGenerator, map_size: Vector2i = Vector2i(60, 44)) -> void:
	_tagged_rooms = tagged_rooms
	_floor_number = floor_number
	_rng = rng
	_map_size = map_size
	_combat_total = 0
	_combat_cleared = 0

	DungeonPainter.paint_floor(tilemap, rooms, corridors, _map_size)

	# Add interior pillars to combat rooms (skip room 0 — player starts there)
	for i in tagged_rooms.size():
		if i > 0 and tagged_rooms[i]["type"] == "combat":
			var rect: Rect2i = tagged_rooms[i]["rect"]
			if rect.size.x >= 11 and rect.size.y >= 9:
				DungeonPainter.add_pillars(tilemap, rect, _map_size, _rng)

	tilemap.notify_runtime_tile_data_update()

	for i in tagged_rooms.size():
		var room_type: String = tagged_rooms[i]["type"]
		if room_type == "combat":
			_combat_total += 1
			_spawn_combat_enemies(i)
		elif room_type == "boss_entry":
			_combat_total += 1
			_create_trigger(i)
		else:
			_create_trigger(i)

	if not _tagged_rooms.is_empty():
		_tagged_rooms[0]["activated"] = true
		call_deferred("_activate_room", 0)


func _create_trigger(index: int) -> void:
	var rd: Dictionary = _tagged_rooms[index]
	var area := Area2D.new()
	area.name = "Trigger_%d" % index
	area.collision_layer = 0
	area.collision_mask = 2  # detect layer-2 bodies (player)
	area.monitoring = true

	# Inset trigger by 3 tiles so corridors don't fire it prematurely
	var inset := 3
	var r: Rect2i = rd["rect"]
	var inner := Rect2i(
		r.position + Vector2i(inset, inset),
		r.size - Vector2i(inset * 2, inset * 2)
	)
	if inner.size.x < 1 or inner.size.y < 1:
		inner = r

	var wr := DungeonPainter.get_room_world_rect(inner, _map_size)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = wr.size
	cs.shape = rs
	area.add_child(cs)
	area.global_position = wr.position + wr.size * 0.5
	area.body_entered.connect(_on_trigger.bind(index))
	add_child(area)


func _on_trigger(body: Node, index: int) -> void:
	if not body.is_in_group("players"):
		return
	room_entered.emit(index)
	if _tagged_rooms[index].get("activated", false):
		return
	_tagged_rooms[index]["activated"] = true
	_activate_room(index)


func _activate_room(index: int) -> void:
	match _tagged_rooms[index]["type"]:
		"trap":       call_deferred("_enter_trap", index)
		"shop":       call_deferred("_enter_shop", index)
		"treasure":   call_deferred("_enter_treasure", index)
		"boss_entry": call_deferred("_enter_boss", index)


# ── Room type handlers ────────────────────────────────────────────────────────

func _spawn_combat_enemies(index: int) -> void:
	var wr := DungeonPainter.get_room_world_rect(_tagged_rooms[index]["rect"], _map_size)
	var composer := WaveComposer.new()
	var enemies := composer.compose(_floor_number, RunManager.get_floor_budget(), _rng)

	if enemies.is_empty():
		_finish_combat(index)
		return

	var alive := [enemies.size()]
	var margin := 2.5 * DungeonPainter.TILE_PX

	for data in enemies:
		var enemy = preload("res://scenes/enemy.tscn").instantiate()
		enemy.max_hp = data.get("hp", 30)
		enemy.move_speed = data.get("speed", 60.0)
		enemy.budget_cost = data.get("cost", 3)
		enemy.elite_modifier = data.get("elite", "")
		var frames_path: String = data.get("frames", "")
		if not frames_path.is_empty():
			enemy.get_node("AnimatedSprite2D").sprite_frames = load(frames_path)

		var ex := wr.position.x + margin + _rng.randf() * maxf(1.0, wr.size.x - margin * 2.0)
		var ey := wr.position.y + margin + _rng.randf() * maxf(1.0, wr.size.y - margin * 2.0)

		add_child(enemy, true)
		enemy.global_position = Vector2(ex, ey)
		enemy.died.connect(func(_e: Node) -> void:
			alive[0] -= 1
			if alive[0] <= 0:
				_finish_combat(index)
		)


func _finish_combat(index: int) -> void:
	_combat_cleared += 1
	var loot = preload("res://scenes/loot_drop.tscn").instantiate()
	loot.position = _room_center(index)
	call_deferred("add_child", loot, true)
	if _combat_cleared >= _combat_total:
		all_combat_cleared.emit()


func _enter_trap(index: int) -> void:
	var rd: Dictionary = _tagged_rooms[index]
	var room_size: Vector2i = rd["rect"].size
	var offset := Vector2i(-(_map_size.x >> 1), -(_map_size.y >> 1))
	var px := float(DungeonPainter.TILE_PX)
	const FILL_CHANCE := 0.35
	const PASSES := 3

	var grid: Array[Array] = []
	for y: int in room_size.y:
		var row: Array[int] = []
		for x: int in room_size.x:
			row.append(1 if _rng.randf() < FILL_CHANCE else 0)
		grid.append(row)

	for _p: int in PASSES:
		var next: Array[Array] = []
		for y: int in room_size.y:
			var row: Array[int] = []
			for x: int in room_size.x:
				var cnt := 0
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= room_size.x or ny >= room_size.y:
							cnt += 1
						else:
							cnt += grid[ny][nx]
				row.append(1 if cnt >= 5 else 0)
			next.append(row)
		grid = next

	for y: int in range(1, room_size.y - 1):
		for x: int in range(1, room_size.x - 1):
			if grid[y][x] == 1:
				var wx := float(rd["rect"].position.x + x + offset.x) * px
				var wy := float(rd["rect"].position.y + y + offset.y) * px
				var center := Vector2(wx + px * 0.5, wy + px * 0.5)

				var vis := ColorRect.new()
				vis.size = Vector2(px, px)
				vis.position = Vector2(wx, wy)
				vis.color = Color(0.9, 0.4, 0.1, 0.12)
				add_child(vis)

				var area := Area2D.new()
				area.collision_layer = 0
				area.collision_mask = 2
				area.set_script(preload("res://scripts/trap_hazard.gd"))
				var cs := CollisionShape2D.new()
				var shape := RectangleShape2D.new()
				shape.size = Vector2(px * 0.85, px * 0.85)
				cs.shape = shape
				area.add_child(cs)
				add_child(area)
				area.global_position = center


func _enter_shop(index: int) -> void:
	var npc = preload("res://scenes/shop_npc.tscn").instantiate()
	npc.position = _room_center(index)
	add_child(npc, true)


func _enter_treasure(index: int) -> void:
	var loot = preload("res://scenes/loot_drop.tscn").instantiate()
	loot.position = _room_center(index)
	add_child(loot, true)


func _enter_boss(index: int) -> void:
	var boss = preload("res://scenes/boss.tscn").instantiate()
	boss.position = _room_center(index)
	boss.died.connect(func() -> void: RunManager.end_run(true))
	add_child(boss, true)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _room_center(index: int) -> Vector2:
	var wr := DungeonPainter.get_room_world_rect(_tagged_rooms[index]["rect"], _map_size)
	return wr.position + wr.size * 0.5


func get_start_position() -> Vector2:
	if _tagged_rooms.is_empty():
		return Vector2.ZERO
	return _room_center(0)
