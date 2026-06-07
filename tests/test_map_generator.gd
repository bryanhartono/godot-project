@tool
extends McpTestSuite

func suite_name() -> String:
    return "map_generator"

func test_dimensions_in_range() -> void:
    for i in 10:
        var md := MapGenerator.generate(i)
        assert_true(md.map_width  >= 7 and md.map_width  <= 10)
        assert_true(md.map_rows   >= 7 and md.map_rows   <= 10)

func test_biome_is_valid() -> void:
    var valid := [&"grass", &"stone", &"snow", &"desert"]
    for i in 10:
        var md := MapGenerator.generate(i)
        assert_true(md.biome in valid)

func test_all_positions_have_tiles() -> void:
    var md := MapGenerator.generate(0)
    for y in md.map_rows:
        for x in md.map_width:
            assert_true(md.tiles.has(Vector2i(x, y)))

func test_deploy_zones_are_walkable() -> void:
    for i in 5:
        var md := MapGenerator.generate(i)
        for y in [0, 1, md.map_rows - 2, md.map_rows - 1]:
            for x in md.map_width:
                var t: MapTile = md.tiles[Vector2i(x, y)]
                assert_eq(t.height, 0)
                assert_true(t.terrain in [&"grass", &"stone", &"snow", &"desert"])
                assert_eq(t.decoration, &"none")

func test_height_values_in_range() -> void:
    var md := MapGenerator.generate(0)
    for pos: Vector2i in md.tiles:
        var h: int = md.tiles[pos].height
        assert_true(h >= 0 and h <= 2)

func test_connectivity_at_least_60_percent() -> void:
    for i in 5:
        var md := MapGenerator.generate(i)
        var walkable: Array[Vector2i] = []
        for pos: Vector2i in md.tiles:
            var t: MapTile = md.tiles[pos]
            if t.terrain not in [&"water", &"lava"] and t.decoration not in [&"rock", &"tree", &"fence"]:
                walkable.append(pos)
        if walkable.is_empty():
            continue
        # BFS from first walkable tile
        var visited: Dictionary = {}
        var queue: Array[Vector2i] = [walkable[0]]
        visited[walkable[0]] = true
        var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
        while queue.size() > 0:
            var cur: Vector2i = queue.pop_front()
            for d in dirs:
                var nb: Vector2i = cur + d
                if visited.has(nb): continue
                if not md.tiles.has(nb): continue
                var t2: MapTile = md.tiles[nb]
                if t2.terrain in [&"water", &"lava"]: continue
                if t2.decoration in [&"rock", &"tree", &"fence"]: continue
                visited[nb] = true
                queue.append(nb)
        var ratio: float = float(visited.size()) / float(walkable.size())
        assert_true(ratio >= 0.60)
