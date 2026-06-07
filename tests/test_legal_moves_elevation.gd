@tool
extends McpTestSuite

func suite_name() -> String:
    return "legal_moves_elevation"

func _make_state(w: int, h: int) -> MatchState:
    var b := Board.new(w, h)
    for y in h:
        for x in w:
            b._terrain[Vector2i(x, y)]    = &"grass"
            b._decoration[Vector2i(x, y)] = &"none"
            b._elevation[Vector2i(x, y)]  = 0
    return MatchState.new(b)

func _make_unit(ms: MatchState, pos: Vector2i, move_range: int, mtype: StringName = &"ground") -> BattleUnit:
    var d := MonsterData.create(&"test", "Test", 1, 5, 1, move_range, 1)
    d.movement_type = mtype
    var u := BattleUnit.new(d, 0, pos)
    ms.board.place_unit(u, pos)
    ms.units.append(u)
    ms.active_unit = u
    return u

func test_flat_moves_budget_respected() -> void:
    var ms := _make_state(5, 1)
    var u  := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)
    assert_false(Vector2i(3, 0) in moves)

func test_uphill_one_costs_two() -> void:
    # Row: h0 at x=0, h1 at x=1, h0 at x=2
    # Unit at x=0 with move_range=2: can reach x=1 (cost 2) but not x=2 (cost 3)
    var ms := _make_state(4, 1)
    ms.board._elevation[Vector2i(1, 0)] = 1
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_false(Vector2i(2, 0) in moves)

func test_uphill_two_blocked_for_ground() -> void:
    # h0 at x=0, h2 at x=1: ground unit cannot jump 2 levels
    var ms := _make_state(3, 1)
    ms.board._elevation[Vector2i(1, 0)] = 2
    var u := _make_unit(ms, Vector2i(0, 0), 3)
    var moves := ms.legal_moves(u)
    assert_false(Vector2i(1, 0) in moves)

func test_downhill_costs_one() -> void:
    # h1 at x=0, h0 at x=1 and x=2: downhill costs 1 each
    var ms := _make_state(4, 1)
    ms.board._elevation[Vector2i(0, 0)] = 1
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)
    assert_false(Vector2i(3, 0) in moves)

func test_flying_ignores_elevation_cost() -> void:
    # h0 at x=0, h2 at x=1, h0 at x=2: flying with move_range=2 reaches all
    var ms := _make_state(5, 1)
    ms.board._elevation[Vector2i(1, 0)] = 2
    var u := _make_unit(ms, Vector2i(0, 0), 2, &"flying")
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)
    assert_true(Vector2i(2, 0) in moves)

func test_water_blocked_for_ground() -> void:
    var ms := _make_state(3, 1)
    ms.board._terrain[Vector2i(1, 0)] = &"water"
    var u := _make_unit(ms, Vector2i(0, 0), 2)
    var moves := ms.legal_moves(u)
    assert_false(Vector2i(1, 0) in moves)

func test_water_passable_for_water_unit() -> void:
    var ms := _make_state(3, 1)
    ms.board._terrain[Vector2i(1, 0)] = &"water"
    var u := _make_unit(ms, Vector2i(0, 0), 2, &"water")
    var moves := ms.legal_moves(u)
    assert_true(Vector2i(1, 0) in moves)

func test_has_moved_returns_empty() -> void:
    var ms := _make_state(3, 1)
    var u  := _make_unit(ms, Vector2i(0, 0), 2)
    u.has_moved = true
    var moves := ms.legal_moves(u)
    assert_eq(moves.size(), 0)
