# scripts/battle/match_view.gd
extends Node2D

## State machine host for a single match.
## Owns: board rendering, sprite management, MatchState, current BaseBattleState.
## All turn/input logic lives in state objects; this file only coordinates and renders.

const TILE_W      := 64
const TILE_H      := 32
const BOARD_W     := 7
const BOARD_H     := 7
const UNIT_SCALE  := 3.0
const SPRITE_LIFT := 8.0

const COLOR_LIGHT   := Color(0.30, 0.42, 0.30)
const COLOR_DARK    := Color(0.24, 0.34, 0.24)
const COLOR_MOVE    := Color(0.30, 0.55, 0.95, 0.45)
const COLOR_ATTACK  := Color(0.90, 0.30, 0.30, 0.85)
const COLOR_ABILITY := Color(0.95, 0.85, 0.20, 0.85)

## Public — states read these directly.
var match_state: MatchState
var config:      MatchConfig

## Private rendering.
var _tiles:   Dictionary = {}   # Vector2i -> Polygon2D
var _sprites: Dictionary = {}   # BattleUnit -> AnimatedSprite2D

## State machine.
var _current_state: BaseBattleState = null

## UI nodes (built in _build_ui).
var _turn_label:   Label
var _result_label: Label
var _info_label:   Label
var _end_btn:      Button
var _auto_btn:     Button
var _overlay:      Node = null   # win/lose overlay (CanvasLayer)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if Engine.has_meta("match_config"):
		config = Engine.get_meta("match_config") as MatchConfig
		Engine.remove_meta("match_config")
	else:
		# Fallback for direct scene testing without skirmish_setup.
		config = MatchConfig.new()
		config.player_squad = SquadPicker.random_squad(10)
		config.enemy_squad  = SquadPicker.random_squad(10)
		config.difficulty   = 2

	match_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_board()
	_build_ui()
	_setup_camera()
	change_state(DeployState.new())

func _unhandled_input(event: InputEvent) -> void:
	if _current_state:
		_current_state.handle_input(self, event)

# ── State machine ─────────────────────────────────────────────────────────────

func change_state(new_state: BaseBattleState) -> void:
	if _current_state:
		_current_state.exit(self)
	_current_state = new_state
	_current_state.enter(self)

# ── Public API for states ─────────────────────────────────────────────────────

func spawn_unit(data: MonsterData, team: int, pos: Vector2i) -> void:
	var unit := BattleUnit.new(data, team, pos)
	match_state.add_unit(unit, pos)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://resources/monsters/%s.tres" % data.sprite_stem())
	spr.scale    = Vector2(UNIT_SCALE, UNIT_SCALE)
	spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
	spr.z_index  = pos.x + pos.y
	spr.play("idle_front")
	if team == 1:
		spr.modulate = Color(1.0, 0.65, 0.65)
	add_child(spr)
	_sprites[unit] = spr

func sync_sprites() -> void:
	for u in _sprites.keys():
		var spr: AnimatedSprite2D = _sprites[u]
		if not u.is_alive():
			spr.queue_free()
			_sprites.erase(u)
		else:
			spr.position = grid_to_screen(u.grid_pos) - Vector2(0, SPRITE_LIFT)
			spr.z_index  = u.grid_pos.x + u.grid_pos.y
			if not spr.is_playing():
				spr.play(spr.animation)

func highlight_tiles(move_targets: Array[Vector2i],
                     atk_targets:  Array[BattleUnit],
                     ability_targets: Array[Vector2i]) -> void:
	for g in _tiles:
		_tiles[g].color = _base_color(g)
	for g in move_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_MOVE
	for u in atk_targets:
		if _tiles.has(u.grid_pos):
			_tiles[u.grid_pos].color = COLOR_ATTACK
	for g in ability_targets:
		if _tiles.has(g):
			_tiles[g].color = COLOR_ABILITY

func clear_highlights() -> void:
	for g in _tiles:
		_tiles[g].color = _base_color(g)

func set_labels(turn: String, result: String, info: String) -> void:
	_turn_label.text   = turn
	_result_label.text = result
	_info_label.text   = info

func show_win_lose_overlay(winner: int) -> void:
	if _overlay != null:
		return
	var layer := CanvasLayer.new()
	_overlay = layer

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	layer.add_child(vbox)

	var banner := Label.new()
	banner.text = "Victory!" if winner == 0 else "Defeat"
	banner.add_theme_font_size_override("font_size", 48)
	vbox.add_child(banner)

	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.pressed.connect(_on_play_again)
	vbox.add_child(again_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	menu_btn.pressed.connect(_on_go_to_menu)
	vbox.add_child(menu_btn)

	add_child(layer)

func hide_win_lose_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_end_turn() -> void:
	if _current_state is PlayerTurnState:
		(_current_state as PlayerTurnState).on_end_turn(self)

func _on_auto_place() -> void:
	if _current_state is DeployState:
		(_current_state as DeployState).auto_place(self)

func _on_play_again() -> void:
	var new_config           := MatchConfig.new()
	new_config.player_squad   = SquadPicker.random_squad(10)
	new_config.enemy_squad    = SquadPicker.random_squad(10)
	new_config.difficulty     = config.difficulty
	Engine.set_meta("match_config", new_config)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _on_go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/skirmish_setup.tscn")

# ── Coordinate helpers ────────────────────────────────────────────────────────

func grid_to_screen(g: Vector2i) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)

func screen_to_grid(s: Vector2) -> Vector2i:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	return Vector2i(roundi((s.x / hw + s.y / hh) * 0.5),
	                roundi((s.y / hh - s.x / hw) * 0.5))

# ── Board construction ────────────────────────────────────────────────────────

func _build_board() -> void:
	var hw      := TILE_W * 0.5
	var hh      := TILE_H * 0.5
	var diamond := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])
	for y in BOARD_H:
		for x in BOARD_W:
			var g    := Vector2i(x, y)
			var poly := Polygon2D.new()
			poly.polygon  = diamond
			poly.position = grid_to_screen(g)
			poly.color    = _base_color(g)
			add_child(poly)
			_tiles[g] = poly

func _base_color(g: Vector2i) -> Color:
	return COLOR_LIGHT if (g.x + g.y) % 2 == 0 else COLOR_DARK

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_turn_label = Label.new()
	_turn_label.position = Vector2(16, 16)
	layer.add_child(_turn_label)

	_result_label = Label.new()
	_result_label.position = Vector2(16, 44)
	layer.add_child(_result_label)

	_end_btn = Button.new()
	_end_btn.text = "End Turn"
	_end_btn.position = Vector2(16, 80)
	_end_btn.pressed.connect(_on_end_turn)
	layer.add_child(_end_btn)

	_info_label = Label.new()
	_info_label.position = Vector2(16, 120)
	layer.add_child(_info_label)

	_auto_btn = Button.new()
	_auto_btn.text = "Auto-place"
	_auto_btn.position = Vector2(16, 160)
	_auto_btn.pressed.connect(_on_auto_place)
	layer.add_child(_auto_btn)

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(BOARD_W >> 1, BOARD_H >> 1))
	cam.zoom     = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()
