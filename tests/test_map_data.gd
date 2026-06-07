@tool
extends McpTestSuite

func suite_name() -> String:
	return "map_data"

func test_map_tile_defaults() -> void:
	var t := MapTile.new()
	assert_eq(t.height, 0)
	assert_eq(t.terrain, &"grass")
	assert_eq(t.decoration, &"none")

func test_map_data_get_tile_returns_tile() -> void:
	var md := MapData.new()
	md.map_width = 7
	md.map_rows  = 7
	md.biome     = &"grass"
	var t := MapTile.new()
	t.height    = 2
	t.terrain   = &"stone"
	t.decoration = &"rock"
	md.tiles[Vector2i(3, 3)] = t
	assert_eq(md.height_at(Vector2i(3, 3)), 2)
	assert_eq(md.terrain_at(Vector2i(3, 3)), &"stone")
	assert_eq(md.decoration_at(Vector2i(3, 3)), &"rock")

func test_map_data_missing_tile_returns_defaults() -> void:
	var md := MapData.new()
	assert_eq(md.height_at(Vector2i(0, 0)), 0)
	assert_eq(md.terrain_at(Vector2i(0, 0)), &"grass")
	assert_eq(md.decoration_at(Vector2i(0, 0)), &"none")
