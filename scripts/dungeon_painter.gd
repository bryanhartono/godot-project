class_name DungeonPainter
extends RefCounted

const TILESET_PATH: String = "res://assets/Tech Dungeon Roguelite - Asset Pack (v7)/tileset x1.png"
const TILE_PX: int = 32
const SOURCE_ID: int = 0

# Atlas coords (col, row) at 32x32px in tileset x1.png
const FLOOR:     Vector2i = Vector2i(32, 1)
const W_TOP:     Vector2i = Vector2i(5,  0)
const W_BOT:     Vector2i = Vector2i(5,  10)
const W_LEFT:    Vector2i = Vector2i(1,  5)
const W_RIGHT:   Vector2i = Vector2i(9,  5)
const W_FILL:    Vector2i = Vector2i(4,  1)
const C_NW:      Vector2i = Vector2i(2,  0)
const C_NE:      Vector2i = Vector2i(8,  0)
const C_SW:      Vector2i = Vector2i(2,  10)
const C_SE:      Vector2i = Vector2i(8,  10)

static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(TILESET_PATH)
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)

	var wall_coords: Array[Vector2i] = [
		W_TOP, W_BOT, W_LEFT, W_RIGHT, W_FILL, C_NW, C_NE, C_SW, C_SE
	]
	var half := TILE_PX / 2.0
	var box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])

	atlas.create_tile(FLOOR)
	for coord: Vector2i in wall_coords:
		atlas.create_tile(coord)

	ts.add_source(atlas, SOURCE_ID)

	for coord: Vector2i in wall_coords:
		var td: TileData = atlas.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, box)

	return ts


# ── Single room (legacy, used by trap_room.tscn) ─────────────────────────────

static func paint_room(tilemap: TileMapLayer, rect: Rect2i) -> void:
	tilemap.tile_set = build_tileset()
	tilemap.clear()
	var offset: Vector2i = -(rect.position + Vector2i(rect.size.x >> 1, rect.size.y >> 1))
	_paint_room_tiles(tilemap, rect, offset)


# ── Full dungeon floor ────────────────────────────────────────────────────────

static func paint_floor(tilemap: TileMapLayer, rooms: Array[Rect2i], corridors: Array[Rect2i], map_size: Vector2i) -> void:
	tilemap.tile_set = build_tileset()
	tilemap.clear()
	var offset: Vector2i = -Vector2i(map_size.x >> 1, map_size.y >> 1)
	for room in rooms:
		_paint_room_tiles(tilemap, room, offset)
	for corridor in corridors:
		_paint_corridor_tiles(tilemap, corridor, offset)
	_add_border_walls(tilemap)


static func add_pillars(tilemap: TileMapLayer, rect: Rect2i, map_size: Vector2i, rng: RandomNumberGenerator) -> void:
	var offset: Vector2i = -Vector2i(map_size.x >> 1, map_size.y >> 1)
	var num: int = rng.randi_range(1, 3)
	for _i in num:
		var cx: int = rng.randi_range(rect.position.x + 2, rect.position.x + rect.size.x - 5)
		var cy: int = rng.randi_range(rect.position.y + 2, rect.position.y + rect.size.y - 5)
		tilemap.set_cell(Vector2i(cx,     cy)     + offset, SOURCE_ID, C_NW)
		tilemap.set_cell(Vector2i(cx + 1, cy)     + offset, SOURCE_ID, C_NE)
		tilemap.set_cell(Vector2i(cx,     cy + 1) + offset, SOURCE_ID, C_SW)
		tilemap.set_cell(Vector2i(cx + 1, cy + 1) + offset, SOURCE_ID, C_SE)


static func get_room_world_rect(rect: Rect2i, map_size: Vector2i) -> Rect2:
	var offset: Vector2i = -Vector2i(map_size.x >> 1, map_size.y >> 1)
	var px := float(TILE_PX)
	return Rect2(
		(rect.position.x + offset.x) * px,
		(rect.position.y + offset.y) * px,
		rect.size.x * px,
		rect.size.y * px
	)


# ── Internal helpers ──────────────────────────────────────────────────────────

static func _paint_room_tiles(tilemap: TileMapLayer, rect: Rect2i, offset: Vector2i) -> void:
	var rx := rect.position.x
	var ry := rect.position.y
	var rw := rect.size.x
	var rh := rect.size.y

	for r in range(ry + 1, ry + rh - 1):
		for c in range(rx + 1, rx + rw - 1):
			tilemap.set_cell(Vector2i(c, r) + offset, SOURCE_ID, FLOOR)

	tilemap.set_cell(Vector2i(rx,          ry)          + offset, SOURCE_ID, C_NW)
	tilemap.set_cell(Vector2i(rx + rw - 1, ry)          + offset, SOURCE_ID, C_NE)
	tilemap.set_cell(Vector2i(rx,          ry + rh - 1) + offset, SOURCE_ID, C_SW)
	tilemap.set_cell(Vector2i(rx + rw - 1, ry + rh - 1) + offset, SOURCE_ID, C_SE)
	for c in range(rx + 1, rx + rw - 1):
		tilemap.set_cell(Vector2i(c, ry)          + offset, SOURCE_ID, W_TOP)
		tilemap.set_cell(Vector2i(c, ry + rh - 1) + offset, SOURCE_ID, W_BOT)
	for r in range(ry + 1, ry + rh - 1):
		tilemap.set_cell(Vector2i(rx,          r) + offset, SOURCE_ID, W_LEFT)
		tilemap.set_cell(Vector2i(rx + rw - 1, r) + offset, SOURCE_ID, W_RIGHT)


static func _paint_corridor_tiles(tilemap: TileMapLayer, corridor: Rect2i, offset: Vector2i) -> void:
	# Widen corridors to 2 tiles so the player can walk through
	var expanded: Rect2i
	if corridor.size.x >= corridor.size.y:
		expanded = Rect2i(corridor.position.x, corridor.position.y, corridor.size.x, 2)
	else:
		expanded = Rect2i(corridor.position.x, corridor.position.y, 2, corridor.size.y)
	for r in range(expanded.position.y, expanded.position.y + expanded.size.y):
		for c in range(expanded.position.x, expanded.position.x + expanded.size.x):
			tilemap.set_cell(Vector2i(c, r) + offset, SOURCE_ID, FLOOR)


static func _add_border_walls(tilemap: TileMapLayer) -> void:
	var floor_set: Dictionary = {}
	for cell: Vector2i in tilemap.get_used_cells():
		if tilemap.get_cell_atlas_coords(cell) == FLOOR:
			floor_set[cell] = true

	var to_place: Dictionary = {}
	for cell: Vector2i in floor_set:
		var cx: int = cell.x
		var cy: int = cell.y
		var has_left:  bool = floor_set.has(Vector2i(cx - 1, cy))
		var has_right: bool = floor_set.has(Vector2i(cx + 1, cy))
		var has_up:    bool = floor_set.has(Vector2i(cx,     cy - 1))
		var has_down:  bool = floor_set.has(Vector2i(cx,     cy + 1))

		if not has_up:    _propose_wall(floor_set, tilemap, to_place, Vector2i(cx,     cy - 1), W_TOP)
		if not has_down:  _propose_wall(floor_set, tilemap, to_place, Vector2i(cx,     cy + 1), W_BOT)
		if not has_left:  _propose_wall(floor_set, tilemap, to_place, Vector2i(cx - 1, cy),     W_LEFT)
		if not has_right: _propose_wall(floor_set, tilemap, to_place, Vector2i(cx + 1, cy),     W_RIGHT)

		# Corners only at true outer corners — both adjacent cardinal edges must be absent
		if not has_left  and not has_up:   _propose_wall(floor_set, tilemap, to_place, Vector2i(cx - 1, cy - 1), C_NW)
		if not has_right and not has_up:   _propose_wall(floor_set, tilemap, to_place, Vector2i(cx + 1, cy - 1), C_NE)
		if not has_left  and not has_down: _propose_wall(floor_set, tilemap, to_place, Vector2i(cx - 1, cy + 1), C_SW)
		if not has_right and not has_down: _propose_wall(floor_set, tilemap, to_place, Vector2i(cx + 1, cy + 1), C_SE)

	for cell: Vector2i in to_place:
		tilemap.set_cell(cell, SOURCE_ID, to_place[cell])


static func _propose_wall(floor_set: Dictionary, tilemap: TileMapLayer, out: Dictionary, cell: Vector2i, tile: Vector2i) -> void:
	if floor_set.has(cell):
		return
	if tilemap.get_cell_source_id(cell) >= 0:
		return
	if out.has(cell) and out[cell] != tile:
		out[cell] = W_FILL
	else:
		out[cell] = tile


# ── Spawn positions (legacy single-room helper) ───────────────────────────────

static func get_spawn_positions(rect: Rect2i) -> Array[Vector2]:
	var px := float(TILE_PX)
	var hw: float = (rect.size.x / 2.0 - 1.5) * px
	var hh: float = (rect.size.y / 2.0 - 1.5) * px
	return [
		Vector2(-hw, 0.0),
		Vector2(hw, 0.0),
		Vector2(0.0, -hh),
		Vector2(0.0, hh),
		Vector2(-hw * 0.6, -hh * 0.6),
		Vector2(hw * 0.6, -hh * 0.6),
		Vector2(-hw * 0.6, hh * 0.6),
		Vector2(hw * 0.6, hh * 0.6),
	]
