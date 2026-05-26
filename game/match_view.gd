extends Node2D

## Thin presentation layer over MatchState. Renders an isometric board with
## Polygon2D diamonds and unit Sprite2Ds, and turns clicks into engine calls.
## Hot-seat: one human controls both teams.

const TILE_W := 64
const TILE_H := 32
const BOARD_W := 7
const BOARD_H := 7
const UNIT_SCALE := 3.0
const SPRITE_LIFT := 24.0  # lifts a 16*scale sprite so it sits on the diamond
const ENTITY_SHEET := "res://assets/Sprites/Outlined_Entities.png"

const COLOR_LIGHT := Color(0.30, 0.42, 0.30)
const COLOR_DARK := Color(0.24, 0.34, 0.24)
const COLOR_MOVE := Color(0.30, 0.55, 0.95, 0.85)
const COLOR_ATTACK := Color(0.90, 0.30, 0.30, 0.85)

var _state: MatchState
var _tiles: Dictionary = {}    # Vector2i -> Polygon2D
var _sprites: Dictionary = {}  # BattleUnit -> Sprite2D
var _selected: BattleUnit = null
var _move_targets: Array[Vector2i] = []
var _atk_targets: Array[BattleUnit] = []
var _turn_label: Label
var _result_label: Label

func _ready() -> void:
	_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_board()
	_setup_units()
	_build_ui()
	_setup_camera()
	_refresh()

func grid_to_screen(g: Vector2i) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)

func screen_to_grid(s: Vector2) -> Vector2i:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var gx := (s.x / hw + s.y / hh) * 0.5
	var gy := (s.y / hh - s.x / hw) * 0.5
	return Vector2i(roundi(gx), roundi(gy))

func _build_board() -> void:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var diamond := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])
	for y in BOARD_H:
		for x in BOARD_W:
			var g := Vector2i(x, y)
			var poly := Polygon2D.new()
			poly.polygon = diamond
			poly.position = grid_to_screen(g)
			poly.color = _base_color(g)
			add_child(poly)
			_tiles[g] = poly

func _base_color(g: Vector2i) -> Color:
	return COLOR_LIGHT if (g.x + g.y) % 2 == 0 else COLOR_DARK

func _setup_units() -> void:
	# Player team (0) — bottom of the board.
	_spawn(0, 8, 3, 3, 1, 0, Vector2i(2, 5))    # row 0: knight (bruiser)
	_spawn(24, 4, 2, 1, 3, 0, Vector2i(3, 6))   # row 24: archer (ranged)
	_spawn(17, 5, 2, 4, 1, 0, Vector2i(4, 5))   # row 17: spider (fast)
	# Enemy team (1) — top of the board.
	_spawn(9, 7, 3, 2, 1, 1, Vector2i(2, 1))    # row 9: goblin
	_spawn(26, 10, 1, 2, 1, 1, Vector2i(3, 0))  # row 26: crab (tank)
	_spawn(30, 4, 3, 4, 1, 1, Vector2i(4, 1))   # row 30: bat (fast)

func _spawn(frame_row: int, hp: int, atk: int, mv: int, rng: int, team: int, pos: Vector2i) -> void:
	var data := MonsterData.create(StringName("u%d" % frame_row), "U%d" % frame_row, 1, hp, atk, mv, rng)
	var unit := BattleUnit.new(data, team, pos)
	_state.add_unit(unit, pos)
	var spr := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(ENTITY_SHEET)
	atlas.region = Rect2(0, frame_row * 16, 16, 16)
	spr.texture = atlas
	spr.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
	if team == 1:
		spr.modulate = Color(1.0, 0.65, 0.65)
	add_child(spr)
	_sprites[unit] = spr

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_turn_label = Label.new()
	_turn_label.position = Vector2(16, 16)
	layer.add_child(_turn_label)
	_result_label = Label.new()
	_result_label.position = Vector2(16, 44)
	layer.add_child(_result_label)
	var btn := Button.new()
	btn.text = "End Turn"
	btn.position = Vector2(16, 80)
	btn.pressed.connect(_on_end_turn)
	layer.add_child(btn)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(BOARD_W / 2, BOARD_H / 2))
	cam.zoom = Vector2(1.5, 1.5)
	add_child(cam)
	cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if _state.winner() != -1:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_tile_clicked(screen_to_grid(get_local_mouse_position()))

func _on_tile_clicked(g: Vector2i) -> void:
	if not _state.board.is_in_bounds(g):
		_deselect()
		return
	var clicked: BattleUnit = _state.board.get_unit_at(g)
	if _selected != null and clicked != null and clicked in _atk_targets:
		_state.attack(_selected, clicked)
		_after_action()
		return
	if _selected != null and g in _move_targets:
		_state.move_unit(_selected, g)
		_after_action()
		return
	if clicked != null and clicked.team == _state.current_team:
		_selected = clicked
		_recompute_targets()
		_refresh()
		return
	_deselect()

func _after_action() -> void:
	if _selected != null and _selected.has_moved and _selected.has_acted:
		_selected = null
		_move_targets = []
		_atk_targets = []
	else:
		_recompute_targets()
	_sync_sprites()
	_refresh()

func _recompute_targets() -> void:
	if _selected == null:
		_move_targets = []
		_atk_targets = []
		return
	_move_targets = [] if _selected.has_moved else _state.legal_moves(_selected)
	_atk_targets = [] if _selected.has_acted else _state.legal_targets(_selected)

func _deselect() -> void:
	_selected = null
	_move_targets = []
	_atk_targets = []
	_refresh()

func _on_end_turn() -> void:
	_state.end_turn()
	_deselect()

func _refresh() -> void:
	for g in _tiles:
		_tiles[g].color = _base_color(g)
	for g in _move_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_MOVE
	for u in _atk_targets:
		if _tiles.has(u.grid_pos):
			_tiles[u.grid_pos].color = COLOR_ATTACK
	_update_labels()

func _sync_sprites() -> void:
	for u in _sprites.keys():
		var spr: Sprite2D = _sprites[u]
		if not u.is_alive():
			spr.queue_free()
			_sprites.erase(u)
		else:
			spr.position = grid_to_screen(u.grid_pos) - Vector2(0, SPRITE_LIFT)

func _update_labels() -> void:
	var w := _state.winner()
	if w == -1:
		_turn_label.text = "Turn: %s" % ("PLAYER" if _state.current_team == 0 else "ENEMY (red tint)")
		_result_label.text = ""
	else:
		_turn_label.text = ""
		_result_label.text = "%s WINS" % ("PLAYER" if w == 0 else "ENEMY")
