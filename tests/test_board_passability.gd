@tool
extends McpTestSuite

func suite_name() -> String:
    return "board_passability"

func _make_board() -> Board:
    var b := Board.new(5, 5)
    for y in 5:
        for x in 5:
            b._terrain[Vector2i(x, y)] = &"grass"
            b._decoration[Vector2i(x, y)] = &"none"
            b._elevation[Vector2i(x, y)] = 0
    return b

func test_ground_on_grass_passable() -> void:
    var b := _make_board()
    assert_true(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_water_unit_passes_water() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"water"
    assert_true(b.is_passable(Vector2i(2, 2), &"water"))

func test_water_unit_blocked_by_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_false(b.is_passable(Vector2i(2, 2), &"water"))

func test_ground_blocked_by_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_lava() -> void:
    var b := _make_board()
    b._terrain[Vector2i(2, 2)] = &"lava"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_ground_blocked_by_rock() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"rock"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_tree() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"tree"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_ground_blocked_by_fence() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"fence"
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))

func test_flying_passes_rock() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"rock"
    assert_true(b.is_passable(Vector2i(2, 2), &"flying"))

func test_flower_does_not_block() -> void:
    var b := _make_board()
    b._decoration[Vector2i(2, 2)] = &"flower"
    assert_true(b.is_passable(Vector2i(2, 2), &"ground"))

func test_elevation_at_returns_height() -> void:
    var b := _make_board()
    b._elevation[Vector2i(1, 1)] = 2
    assert_eq(b.elevation_at(Vector2i(1, 1)), 2)
    assert_eq(b.elevation_at(Vector2i(0, 0)), 0)

func test_out_of_bounds_not_passable() -> void:
    var b := _make_board()
    assert_false(b.is_passable(Vector2i(-1, 0), &"ground"))
    assert_false(b.is_passable(Vector2i(5, 5), &"flying"))

func test_load_map_sets_dimensions() -> void:
    var md := MapData.new()
    md.map_width = 9
    md.map_rows  = 8
    md.biome     = &"stone"
    for y in 8:
        for x in 9:
            var t := MapTile.new()
            t.height = 0
            t.terrain = &"stone"
            t.decoration = &"none"
            md.tiles[Vector2i(x, y)] = t
    var b := Board.new()
    b.load_map(md)
    assert_eq(b.width, 9)
    assert_eq(b.height, 8)

func test_load_map_copies_terrain() -> void:
    var md := MapData.new()
    md.map_width = 3
    md.map_rows  = 3
    md.biome     = &"grass"
    for y in 3:
        for x in 3:
            var t := MapTile.new()
            md.tiles[Vector2i(x, y)] = t
    md.tiles[Vector2i(1, 1)].terrain = &"water"
    md.tiles[Vector2i(2, 2)].decoration = &"rock"
    md.tiles[Vector2i(0, 0)].height = 2
    var b := Board.new()
    b.load_map(md)
    assert_false(b.is_passable(Vector2i(1, 1), &"ground"))
    assert_false(b.is_passable(Vector2i(2, 2), &"ground"))
    assert_eq(b.elevation_at(Vector2i(0, 0)), 2)
