extends Node2D

## Thin presentation layer over MatchState. Renders an isometric board with
## Polygon2D diamonds and AnimatedSprite2D units, and turns clicks into engine calls.
## Hot-seat: one human controls both teams.

const TILE_W := 64
const TILE_H := 32
const BOARD_W := 7
const BOARD_H := 7
const UNIT_SCALE := 3.0
const SPRITE_LIFT := 8.0

const COLOR_LIGHT   := Color(0.30, 0.42, 0.30)
const COLOR_DARK    := Color(0.24, 0.34, 0.24)
const COLOR_MOVE    := Color(0.30, 0.55, 0.95, 0.45)
const COLOR_ATTACK  := Color(0.90, 0.30, 0.30, 0.85)
const COLOR_ABILITY := Color(0.95, 0.85, 0.20, 0.85)

var _state: MatchState
var _tiles: Dictionary = {}          # Vector2i -> Polygon2D
var _sprites: Dictionary = {}        # BattleUnit -> AnimatedSprite2D
var _selected: BattleUnit = null
var _move_targets: Array[Vector2i] = []
var _atk_targets: Array[BattleUnit] = []
var _ability_targets: Array[Vector2i] = []
var _turn_label: Label
var _result_label: Label
var _info_label: Label

func _ready() -> void:
	_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_board()
	_load_squads()
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

func _load_squads() -> void:
	# Player squad (team 0) -- bottom rows
	var player_squad: Array = [
		[&"knight", Vector2i(2, 5)],
		[&"archer", Vector2i(3, 6)],
		[&"spider", Vector2i(4, 5)],
	]
	for entry in player_squad:
		_spawn_unit(MonsterDB.get_monster(entry[0]), 0, entry[1])
	# Enemy squad (team 1) -- top rows, red-tinted
	var enemy_squad: Array = [
		[&"goblin", Vector2i(2, 1)],
		[&"crab",   Vector2i(3, 0)],
		[&"bat",    Vector2i(4, 1)],
	]
	for entry in enemy_squad:
		_spawn_unit(MonsterDB.get_monster(entry[0]), 1, entry[1])

func _spawn_unit(data: MonsterData, team: int, pos: Vector2i) -> void:
	var unit := BattleUnit.new(data, team, pos)
	_state.add_unit(unit, pos)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://resources/monsters/%s.tres" % data.id)
	spr.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
	spr.z_index = pos.x + pos.y
	spr.play("idle")
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
	_info_label = Label.new()
	_info_label.position = Vector2(16, 120)
	layer.add_child(_info_label)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(BOARD_W / 2, BOARD_H / 2))
	cam.zoom = Vector2(1.0, 1.0)
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
	# Ability target takes priority over normal attack target
	if _selected != null and g in _ability_targets:
		_state.use_ability(_selected, g)
		_after_action()
		return
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
		_ability_targets = []
	else:
		_recompute_targets()
	_sync_sprites()
	_refresh()

func _recompute_targets() -> void:
	if _selected == null:
		_move_targets = []
		_atk_targets = []
		_ability_targets = []
		return
	_move_targets.clear()
	if not _selected.has_moved:
		_move_targets = _state.legal_moves(_selected)
	_atk_targets.clear()
	if not _selected.has_acted:
		_atk_targets = _state.legal_targets(_selected)
	_ability_targets = _state.legal_ability_targets(_selected)

func _deselect() -> void:
	_selected = null
	_move_targets = []
	_atk_targets = []
	_ability_targets = []
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
	for g in _ability_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_ABILITY
	_update_labels()

func _sync_sprites() -> void:
	for u in _sprites.keys():
		var spr: AnimatedSprite2D = _sprites[u]
		if not u.is_alive():
			spr.queue_free()
			_sprites.erase(u)
		else:
			spr.position = grid_to_screen(u.grid_pos) - Vector2(0, SPRITE_LIFT)
			spr.z_index = u.grid_pos.x + u.grid_pos.y
			if not spr.is_playing():
				spr.play("idle")

func _update_labels() -> void:
	var w := _state.winner()
	if w == -1:
		_turn_label.text = "Turn: %s" % ("PLAYER" if _state.current_team == 0 else "ENEMY (red tint)")
		_result_label.text = ""
	else:
		_turn_label.text = ""
		_result_label.text = "%s WINS" % ("PLAYER" if w == 0 else "ENEMY")
	if _selected != null:
		var ab_text := ""
		if _selected.data.ability != null:
			ab_text = "  [%s]" % AbilityData.Type.keys()[_selected.data.ability.type]
		_info_label.text = "%s  HP:%d/%d%s" % [
			_selected.data.display_name,
			_selected.current_hp,
			_selected.data.max_hp,
			ab_text
		]
	else:
		_info_label.text = ""
