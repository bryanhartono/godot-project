class_name DungeonPainter
extends RefCounted

const TILESET_PATH: String = "res://assets/Tech Dungeon Roguelite - Asset Pack (v7)/tileset x1.png"
const TILE_PX: int = 32
const SOURCE_ID: int = 0

# Atlas coords (col, row) at 32x32px in tileset x1.png
const FLOOR:     Vector2i = Vector2i(32, 1)   # dark navy solid
const W_TOP:     Vector2i = Vector2i(5,  0)   # north-facing wall face
const W_BOT:     Vector2i = Vector2i(5,  10)  # south-facing wall face
const W_LEFT:    Vector2i = Vector2i(1,  5)   # west wall
const W_RIGHT:   Vector2i = Vector2i(9,  5)   # east wall
const W_FILL:    Vector2i = Vector2i(4,  1)   # solid interior wall
const C_NW:      Vector2i = Vector2i(2,  0)   # corner top-left
const C_NE:      Vector2i = Vector2i(8,  0)   # corner top-right
const C_SW:      Vector2i = Vector2i(2,  10)  # corner bottom-left
const C_SE:      Vector2i = Vector2i(8,  10)  # corner bottom-right

static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_PX, TILE_PX)

	# Physics layer for wall collision
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
		var td: TileData = atlas.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, box)

	ts.add_source(atlas, SOURCE_ID)
	return ts


static func paint_room(tilemap: TileMapLayer, rect: Rect2i) -> void:
	tilemap.tile_set = build_tileset()
	tilemap.clear()

	# Center the room at local origin (game world places room at Vector2.ZERO)
	var offset := Vector2i(
		-(rect.position.x + rect.size.x / 2),
		-(rect.position.y + rect.size.y / 2)
	)

	var rx: int = rect.position.x
	var ry: int = rect.position.y
	var rw: int = rect.size.x
	var rh: int = rect.size.y

	# Floor (interior, inset by 1 on each side for wall border)
	for r in range(ry + 1, ry + rh - 1):
		for c in range(rx + 1, rx + rw - 1):
			tilemap.set_cell(Vector2i(c, r) + offset, SOURCE_ID, FLOOR)

	# Top wall row
	tilemap.set_cell(Vector2i(rx, ry) + offset, SOURCE_ID, C_NW)
	for c in range(rx + 1, rx + rw - 1):
		tilemap.set_cell(Vector2i(c, ry) + offset, SOURCE_ID, W_TOP)
	tilemap.set_cell(Vector2i(rx + rw - 1, ry) + offset, SOURCE_ID, C_NE)

	# Bottom wall row
	tilemap.set_cell(Vector2i(rx, ry + rh - 1) + offset, SOURCE_ID, C_SW)
	for c in range(rx + 1, rx + rw - 1):
		tilemap.set_cell(Vector2i(c, ry + rh - 1) + offset, SOURCE_ID, W_BOT)
	tilemap.set_cell(Vector2i(rx + rw - 1, ry + rh - 1) + offset, SOURCE_ID, C_SE)

	# Left and right walls
	for r in range(ry + 1, ry + rh - 1):
		tilemap.set_cell(Vector2i(rx, r) + offset, SOURCE_ID, W_LEFT)
		tilemap.set_cell(Vector2i(rx + rw - 1, r) + offset, SOURCE_ID, W_RIGHT)


static func get_spawn_positions(rect: Rect2i) -> Array[Vector2]:
	# Room is painted centered at origin; spawn points radiate from center
	var px := float(TILE_PX)
	var hw: float = (rect.size.x / 2.0 - 1.5) * px
	var hh: float = (rect.size.y / 2.0 - 1.5) * px

	var positions: Array[Vector2] = [
		Vector2(-hw, 0.0),
		Vector2(hw, 0.0),
		Vector2(0.0, -hh),
		Vector2(0.0, hh),
		Vector2(-hw * 0.6, -hh * 0.6),
		Vector2(hw * 0.6, -hh * 0.6),
		Vector2(-hw * 0.6, hh * 0.6),
		Vector2(hw * 0.6, hh * 0.6),
	]
	return positions
