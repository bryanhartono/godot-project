# scripts/battle/match_view.gd
extends Node2D

## State machine host for a single match.

## Explicit preloads so the VS Code GDScript language server resolves these
## class_name types locally. Godot uses the global class registry at runtime.
const BaseBattleState = preload("res://scripts/battle/states/base_battle_state.gd")
const DeployState     = preload("res://scripts/battle/states/deploy_state.gd")
const PlayerTurnState = preload("res://scripts/battle/states/player_turn_state.gd")
const WinLoseState    = preload("res://scripts/battle/states/win_lose_state.gd")
const AiTurnState     = preload("res://scripts/battle/states/ai_turn_state.gd")
const SquadPicker     = preload("res://scripts/battle/squad_picker.gd")

const TILE_W      := 64
const TILE_H      := 32
const UNIT_SCALE  := 3.0
const SPRITE_LIFT := 8.0
const BAR_W       := 18.0
const BAR_H       := 2.5
const BAR_LIFT    := SPRITE_LIFT + 28.0

const COLOR_LIGHT   := Color(0.38, 0.47, 0.25)
const COLOR_DARK    := Color(0.26, 0.33, 0.17)
const PANEL_BG      := Color(0.08, 0.04, 0.01, 0.92)
const INIT_SLOTS    := 7
const UNIT_Z_BASE   := 200
const ELEV_LIFT     := TILE_H      # screen pixels raised per height level (32px)

## Public — states read these directly.
var match_state: MatchState
var config:      MatchConfig

## Private rendering.
var _map_data:   MapData    = null
var _tiles:      Dictionary = {}   # Vector2i -> Polygon2D
var _hover_poly: Polygon2D  = null # mouse-hover tile indicator
var _sprites:    Dictionary = {}   # BattleUnit -> AnimatedSprite2D
var _idle_anims: Dictionary = {}   # BattleUnit -> StringName
var _hp_bars:    Dictionary = {}   # BattleUnit -> {bg: Polygon2D, fill: Polygon2D}

## State machine.
var _current_state: BaseBattleState = null

## UI nodes.
var _turn_label:          Label
var _info_label:          Label
var _attack_btn:          Button
var _cancel_btn:          Button
var _wait_btn:            Button
var _auto_btn:            Button
var _path_overlays:       Array[Polygon2D]      = []
var _ghost_spr:           AnimatedSprite2D      = null
var _active_highlight:    Polygon2D             = null
var _initiative_slots:    Array[Panel]          = []
var _initiative_styles:   Array[StyleBoxFlat]   = []
var _initiative_textures: Array[TextureRect]    = []
var _stat_popup_layer:    CanvasLayer = null
var _unit_card_layer:     CanvasLayer = null
var _card_map:            Dictionary  = {}   # MonsterData -> Control
var _dragging_data:       MonsterData = null
var _drag_ghost                       = null  # AnimatedSprite2D during deploy drag
var _overlay:             Node = null
var _loot_overlay:        Node = null
var _again_btn:           Button = null
var _menu_btn:            Button = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if Engine.has_meta("match_config"):
		config = Engine.get_meta("match_config") as MatchConfig
		Engine.remove_meta("match_config")
	else:
		config = MatchConfig.new()
		config.player_squad = SquadPicker.random_squad(10)
		config.enemy_squad  = SquadPicker.random_squad(10)
		config.difficulty   = 2

	_map_data  = MapGenerator.generate()
	var board  := Board.new()
	board.load_map(_map_data)
	match_state = MatchState.new(board)

	_build_background()
	_build_board(_map_data)
	_build_ui()
	_setup_camera()
	change_state(DeployState.new())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _hover_poly != null and match_state != null:
		var g := screen_to_grid(get_local_mouse_position())
		if match_state.board.is_in_bounds(g):
			_hover_poly.position = grid_to_screen(g, match_state.board.elevation_at(g))
			_hover_poly.visible  = true
		else:
			_hover_poly.visible = false

	# ── Card drag ─────────────────────────────────────────────────────────────
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging_data == null and not _card_map.is_empty():
			var mpos := get_viewport().get_mouse_position()
			for data: MonsterData in _card_map:
				var card: Control = _card_map[data]
				if card.get_global_rect().has_point(mpos):
					_start_card_drag(data, card)
					get_viewport().set_input_as_handled()
					return

	if _dragging_data != null:
		if event is InputEventMouseMotion and _drag_ghost != null:
			_drag_ghost.position = get_viewport().get_mouse_position() - Vector2(0, 52)
		elif event is InputEventMouseButton and not event.pressed:
			_finish_card_drag()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _current_state:
		_current_state.handle_input(self, event)

# ── State machine ─────────────────────────────────────────────────────────────

func change_state(new_state: BaseBattleState) -> void:
	if _current_state:
		_current_state.exit(self)
	_current_state = new_state
	_current_state.enter(self)

## Called by states when the active unit's turn ends; picks the next unit.
func advance_turn() -> void:
	match_state.advance_initiative()
	sync_sprites()
	_update_initiative_strip()
	if match_state.winner() != -1:
		change_state(WinLoseState.new())
		return
	if match_state.active_unit == null:
		return
	if match_state.active_unit.team == 0:
		change_state(PlayerTurnState.new())
	else:
		change_state(AiTurnState.new(config.difficulty))

# ── Public API for states ─────────────────────────────────────────────────────

func spawn_unit(data: MonsterData, team: int, pos: Vector2i) -> void:
	var unit := BattleUnit.new(data, team, pos)
	match_state.add_unit(unit, pos)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://resources/units/%s.tres" % data.sprite_stem())
	spr.scale    = Vector2(UNIT_SCALE, UNIT_SCALE)
	spr.position = grid_to_screen(pos, match_state.board.elevation_at(pos)) - Vector2(0, SPRITE_LIFT)
	spr.z_index  = (pos.x + pos.y) * 3 + match_state.board.elevation_at(pos) + UNIT_Z_BASE
	var idle: StringName = "idle_back" if team == 0 else "idle_front"
	_idle_anims[unit] = idle
	spr.play(idle)
	if team == 1:
		spr.flip_h   = true
		spr.modulate = Color(1.0, 0.65, 0.65)
	add_child(spr)
	_sprites[unit] = spr
	_create_hp_bar(unit, pos)

func sync_sprites() -> void:
	for u in _sprites.keys():
		var spr: AnimatedSprite2D = _sprites[u]
		if not u.is_alive():
			AudioManager.play_sfx(&"unit_death")
			spr.queue_free()
			_sprites.erase(u)
			_idle_anims.erase(u)
			if _hp_bars.has(u):
				_hp_bars[u]["bg"].queue_free()
				_hp_bars[u]["fill"].queue_free()
				_hp_bars.erase(u)
		else:
			var screen_pos := grid_to_screen(u.grid_pos, match_state.board.elevation_at(u.grid_pos))
			spr.position = screen_pos - Vector2(0, SPRITE_LIFT)
			spr.z_index  = (u.grid_pos.x + u.grid_pos.y) * 3 + match_state.board.elevation_at(u.grid_pos) + UNIT_Z_BASE
			if not spr.is_playing():
				spr.play(_idle_anims.get(u, &"idle_front"))
			if _hp_bars.has(u):
				var bar_pos := screen_pos - Vector2(0, BAR_LIFT)
				var z: int = (u.grid_pos.x + u.grid_pos.y) * 3 + match_state.board.elevation_at(u.grid_pos) + UNIT_Z_BASE + 1
				_hp_bars[u]["bg"].position   = bar_pos
				_hp_bars[u]["fill"].position = bar_pos
				_hp_bars[u]["bg"].z_index    = z
				_hp_bars[u]["fill"].z_index  = z
				_update_hp_bar(u)

func play_attack_animation(attacker: BattleUnit, target: BattleUnit = null) -> void:
	var spr: AnimatedSprite2D = _sprites.get(attacker)
	if spr == null:
		return
	var atk_anim: StringName  = "attack_back"  if attacker.team == 0 else "attack_front"
	var idle_anim: StringName = _idle_anims.get(attacker, &"idle_front")
	spr.play(atk_anim)
	AudioManager.play_sfx(&"attack")
	# Hit shake on target after half the attack animation.
	if target != null:
		get_tree().create_timer(0.2).timeout.connect(func():
			_play_hit_shake(target)
		)
	get_tree().create_timer(0.4).timeout.connect(func():
		if _sprites.has(attacker) and is_instance_valid(_sprites[attacker]):
			_sprites[attacker].play(idle_anim)
	)

func _play_hit_shake(unit: BattleUnit) -> void:
	var spr: AnimatedSprite2D = _sprites.get(unit)
	if spr == null:
		return
	var origin: Vector2 = spr.position
	var d: float = 5.0
	var t := create_tween()
	t.tween_property(spr, "position", origin + Vector2(d, 0),    0.04)
	t.tween_property(spr, "position", origin - Vector2(d, 0),    0.04)
	t.tween_property(spr, "position", origin + Vector2(d*0.5,0), 0.03)
	t.tween_property(spr, "position", origin,                    0.03)

func show_attack_btn(show: bool) -> void:
	if _attack_btn != null:
		_attack_btn.visible = show

func show_cancel_btn(show: bool) -> void:
	if _cancel_btn != null:
		_cancel_btn.visible = show

func show_wait_btn(show: bool) -> void:
	if _wait_btn != null:
		_wait_btn.visible = show

func set_deploy_mode(on: bool) -> void:
	if _auto_btn    != null: _auto_btn.visible    = on
	if _wait_btn    != null: _wait_btn.visible     = not on
	if _attack_btn  != null: _attack_btn.visible   = false
	if _cancel_btn  != null: _cancel_btn.visible   = false

func show_move_preview(unit: BattleUnit, path: Array[Vector2i], atk_tiles: Array[Vector2i] = []) -> void:
	clear_move_preview()
	if path.size() < 2:
		return
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var diamond := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])
	# Attack range from destination — red tint behind path trail
	for g in atk_tiles:
		var poly := Polygon2D.new()
		poly.polygon  = diamond
		poly.position = grid_to_screen(g, match_state.board.elevation_at(g))
		poly.color    = Color(0.90, 0.20, 0.20, 0.50)
		poly.z_index  = 100
		add_child(poly)
		_path_overlays.append(poly)
	# Path trail — intermediate tiles
	for i in range(1, path.size() - 1):
		var poly := Polygon2D.new()
		poly.polygon  = diamond
		poly.position = grid_to_screen(path[i], match_state.board.elevation_at(path[i]))
		poly.color    = Color(0.20, 0.80, 0.90, 0.55)
		poly.z_index  = 100
		add_child(poly)
		_path_overlays.append(poly)
	# Destination tile — brighter
	var dest_poly := Polygon2D.new()
	dest_poly.polygon  = diamond
	dest_poly.position = grid_to_screen(path[-1], match_state.board.elevation_at(path[-1]))
	dest_poly.color    = Color(0.20, 0.85, 0.95, 0.75)
	dest_poly.z_index  = 100
	add_child(dest_poly)
	_path_overlays.append(dest_poly)
	# Ghost sprite at destination
	var src_spr: AnimatedSprite2D = _sprites.get(unit)
	if src_spr != null:
		_ghost_spr               = AnimatedSprite2D.new()
		_ghost_spr.sprite_frames = src_spr.sprite_frames
		_ghost_spr.scale         = src_spr.scale
		_ghost_spr.flip_h        = src_spr.flip_h
		_ghost_spr.modulate      = Color(1.0, 1.0, 1.0, 0.40)
		_ghost_spr.position      = grid_to_screen(path[-1], match_state.board.elevation_at(path[-1])) - Vector2(0, SPRITE_LIFT)
		_ghost_spr.z_index       = (path[-1].x + path[-1].y) * 3 + match_state.board.elevation_at(path[-1]) + UNIT_Z_BASE - 1
		_ghost_spr.play(_idle_anims.get(unit, &"idle_front"))
		add_child(_ghost_spr)

func clear_move_preview(keep_ghost: bool = false) -> void:
	for poly in _path_overlays:
		if is_instance_valid(poly):
			poly.queue_free()
	_path_overlays.clear()
	if not keep_ghost and _ghost_spr != null and is_instance_valid(_ghost_spr):
		_ghost_spr.queue_free()
		_ghost_spr = null

func walk_unit_to(unit: BattleUnit, path: Array[Vector2i], on_done: Callable) -> void:
	var spr: AnimatedSprite2D = _sprites.get(unit)
	if spr == null or path.size() < 2:
		on_done.call()
		return
	var t := create_tween()
	for i in range(1, path.size()):
		t.tween_property(spr, "position",
			grid_to_screen(path[i], match_state.board.elevation_at(path[i])) - Vector2(0, SPRITE_LIFT), 0.12)
	t.tween_callback(on_done)

func show_unit_popup(unit: BattleUnit) -> void:
	hide_unit_popup()
	var layer := CanvasLayer.new()
	layer.layer = 5
	_stat_popup_layer = layer
	add_child(layer)

	# Full-screen transparent catcher — any click closes the popup
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			hide_unit_popup()
	)
	layer.add_child(catcher)

	# Convert world position to screen position accounting for camera
	var world_pos: Vector2 = grid_to_screen(unit.grid_pos, match_state.board.elevation_at(unit.grid_pos)) - Vector2(0, SPRITE_LIFT + 48)
	var screen_pos: Vector2 = get_global_transform_with_canvas() * world_pos

	var popup := PanelContainer.new()
	popup.position = screen_pos - Vector2(70, 100)
	popup.theme = AppTheme.game_theme
	layer.add_child(popup)

	# Clamp so popup stays on screen
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	popup.position.x = clampf(popup.position.x, 6.0, vp_size.x - 146.0)
	popup.position.y = clampf(popup.position.y, 80.0, vp_size.y - 200.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = unit.data.display_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for line: String in [
		"HP   %d / %d" % [unit.current_hp, unit.data.max_hp],
		"ATK  %d" % unit.data.atk,
		"SPD  %d" % unit.data.speed,
		"MOV  %d" % unit.data.move_range,
	]:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(lbl)

	if unit.data.ability != null:
		var ab_lbl := Label.new()
		ab_lbl.text = AbilityData.Type.keys()[unit.data.ability.type]
		ab_lbl.add_theme_font_size_override("font_size", 12)
		ab_lbl.modulate = Color(0.95, 0.85, 0.20)
		ab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ab_lbl)

func hide_unit_popup() -> void:
	if _stat_popup_layer != null:
		_stat_popup_layer.queue_free()
		_stat_popup_layer = null

func _create_hp_bar(unit: BattleUnit, pos: Vector2i) -> void:
	var bar_pos := grid_to_screen(pos, match_state.board.elevation_at(pos)) - Vector2(0, BAR_LIFT)
	var z       := (pos.x + pos.y) * 3 + match_state.board.elevation_at(pos) + UNIT_Z_BASE + 1
	var hw      := BAR_W * 0.5
	var hh      := BAR_H * 0.5
	var bg_rect := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	var bg := Polygon2D.new()
	bg.polygon  = bg_rect
	bg.color    = Color(0.12, 0.12, 0.12, 0.85)
	bg.position = bar_pos
	bg.z_index  = z
	add_child(bg)
	var fill := Polygon2D.new()
	fill.position = bar_pos
	fill.z_index  = z
	add_child(fill)
	_hp_bars[unit] = {"bg": bg, "fill": fill}
	_update_hp_bar(unit)

func _update_hp_bar(unit: BattleUnit) -> void:
	var fill: Polygon2D = _hp_bars[unit]["fill"]
	var ratio := clampf(float(unit.current_hp) / float(unit.data.max_hp), 0.0, 1.0)
	var fw    := BAR_W * ratio
	var hh    := BAR_H * 0.5
	var left  := -BAR_W * 0.5
	fill.polygon = PackedVector2Array([
		Vector2(left, -hh), Vector2(left + fw, -hh),
		Vector2(left + fw,  hh), Vector2(left,  hh)
	])
	if ratio > 0.6:
		fill.color = Color(0.20, 0.85, 0.20)
	elif ratio > 0.3:
		fill.color = Color(0.90, 0.75, 0.10)
	else:
		fill.color = Color(0.90, 0.15, 0.15)

func highlight_tiles(move_targets: Array[Vector2i],
					 atk_targets:  Array[BattleUnit],
					 ability_targets: Array[Vector2i]) -> void:
	for g in _tiles:
		_tiles[g].color = Color(0, 0, 0, 0)
	for g in move_targets:
		if _tiles.has(g):
			_tiles[g].color = Color(0.30, 0.55, 0.95, 0.45)
	for u in atk_targets:
		if _tiles.has(u.grid_pos):
			_tiles[u.grid_pos].color = Color(0.90, 0.20, 0.20, 0.55)
	for g in ability_targets:
		if _tiles.has(g):
			_tiles[g].color = Color(0.95, 0.85, 0.20, 0.55)

func clear_highlights() -> void:
	for g in _tiles:
		_tiles[g].color = Color(0, 0, 0, 0)

func highlight_active_unit(unit: BattleUnit) -> void:
	if _active_highlight == null or unit == null:
		return
	_active_highlight.position = grid_to_screen(unit.grid_pos, match_state.board.elevation_at(unit.grid_pos))
	_active_highlight.visible  = true

func clear_active_highlight() -> void:
	if _active_highlight != null:
		_active_highlight.visible = false

func set_labels(turn: String, _result: String, info: String) -> void:
	_turn_label.text = turn
	_info_label.text = info

# ── Unit card deploy tray ─────────────────────────────────────────────────────

func show_unit_cards(queue: Array[MonsterData]) -> void:
	hide_unit_cards()
	_unit_card_layer = CanvasLayer.new()
	_unit_card_layer.layer = 3
	add_child(_unit_card_layer)

	# Tray anchored above the bottom panel
	var tray_ctrl := Control.new()
	tray_ctrl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tray_ctrl.offset_top    = -96 - 96 - 10
	tray_ctrl.offset_bottom = -96 - 6
	tray_ctrl.theme = AppTheme.game_theme
	_unit_card_layer.add_child(tray_ctrl)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	tray_ctrl.add_child(scroll)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_theme_constant_override("separation", 8)
	scroll.add_child(hbox)

	_card_map.clear()
	for data: MonsterData in queue:
		var card := _build_unit_card(data)
		hbox.add_child(card)
		_card_map[data] = card

func _build_unit_card(data: MonsterData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(68, 100)
	card.mouse_filter        = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# Sprite thumbnail
	var frames: SpriteFrames = load("res://resources/units/%s.tres" % data.sprite_stem())
	var anim: StringName = &"idle_front" if frames.has_animation(&"idle_front") else frames.get_animation_names()[0]
	var icon := TextureRect.new()
	icon.texture               = frames.get_frame_texture(anim, 0)
	icon.texture_filter        = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size   = Vector2(0, 44)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = data.display_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	for line: String in ["ATK %d" % data.atk, "SPD %d" % data.speed]:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(lbl)

	return card

func remove_unit_card(data: MonsterData) -> void:
	if _card_map.has(data):
		(_card_map[data] as Control).queue_free()
		_card_map.erase(data)

func hide_unit_cards() -> void:
	_dragging_data = null
	_drag_ghost    = null
	_card_map.clear()
	if _unit_card_layer != null:
		_unit_card_layer.queue_free()
		_unit_card_layer = null

func _start_card_drag(data: MonsterData, card: Control) -> void:
	_dragging_data = data
	card.modulate  = Color(1.0, 1.0, 1.0, 0.30)

	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames  = load("res://resources/units/%s.tres" % data.sprite_stem())
	ghost.scale          = Vector2(UNIT_SCALE + 1.0, UNIT_SCALE + 1.0)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate       = Color(1.0, 1.0, 1.0, 0.90)
	ghost.z_index        = 100
	ghost.play("idle_front")
	ghost.position = get_viewport().get_mouse_position() - Vector2(0, 52)
	_unit_card_layer.add_child(ghost)
	_drag_ghost = ghost

func _finish_card_drag() -> void:
	var data := _dragging_data
	_dragging_data = null

	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null

	if _card_map.has(data):
		(_card_map[data] as Control).modulate = Color(1, 1, 1, 1)

	var grid_pos := screen_to_grid(get_local_mouse_position())
	if _current_state is DeployState:
		(_current_state as DeployState).on_card_dropped(self, data, grid_pos)

# ── Win/lose + loot overlays ──────────────────────────────────────────────────

func show_win_lose_overlay(winner: int) -> void:
	if _overlay != null:
		return
	var layer := CanvasLayer.new()
	_overlay = layer

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.55)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = AppTheme.game_theme
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var banner := Label.new()
	banner.text = "Victory!" if winner == 0 else "Defeat"
	banner.add_theme_font_size_override("font_size", 48)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(banner)

	_again_btn = Button.new()
	_again_btn.text     = "Play Again"
	_again_btn.disabled = true
	_again_btn.pressed.connect(_on_play_again)
	vbox.add_child(_again_btn)

	_menu_btn = Button.new()
	_menu_btn.text     = "Menu"
	_menu_btn.disabled = true
	_menu_btn.pressed.connect(_on_go_to_menu)
	vbox.add_child(_menu_btn)

	add_child(layer)
	if config.is_ranked:
		PlayerProfile.update_trophies(winner == 0)
	_show_loot_overlay(winner == 0)

func hide_win_lose_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null

func _show_loot_overlay(won: bool) -> void:
	var result: Dictionary = PlayerProfile.roll_loot(won)
	var layer := CanvasLayer.new()
	_loot_overlay = layer

	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.70)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = AppTheme.game_theme
	layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Rewards"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var gems_lbl := Label.new()
	gems_lbl.text = "+%d gems" % result["gems"]
	gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gems_lbl)

	var monster_id: StringName = result["monster"]
	if monster_id != &"":
		var mon_lbl := Label.new()
		mon_lbl.text = "%s obtained!" % MonsterDB.get_monster(monster_id).display_name
		mon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(mon_lbl)

	var collect_btn := Button.new()
	collect_btn.text = "Collect"
	collect_btn.pressed.connect(_on_collect_loot)
	vbox.add_child(collect_btn)

	add_child(layer)

func _on_collect_loot() -> void:
	AudioManager.play_sfx(&"ui_click")
	if _loot_overlay != null:
		_loot_overlay.queue_free()
		_loot_overlay = null
	if _again_btn:
		_again_btn.disabled = false
	if _menu_btn:
		_menu_btn.disabled = false

# ── Button callbacks ──────────────────────────────────────────────────────────

func _on_wait() -> void:
	AudioManager.play_sfx(&"ui_click")
	if _current_state is PlayerTurnState:
		(_current_state as PlayerTurnState).on_wait(self)

func _on_attack() -> void:
	AudioManager.play_sfx(&"ui_click")
	if _current_state is PlayerTurnState:
		(_current_state as PlayerTurnState).on_attack(self)

func _on_cancel() -> void:
	AudioManager.play_sfx(&"ui_click")
	if _current_state is PlayerTurnState:
		(_current_state as PlayerTurnState).on_cancel(self)

func _on_auto_place() -> void:
	AudioManager.play_sfx(&"ui_click")
	if _current_state is DeployState:
		(_current_state as DeployState).auto_place(self)

func _on_play_again() -> void:
	AudioManager.play_sfx(&"ui_click")
	var new_config        := MatchConfig.new()
	new_config.player_squad.assign(PlayerProfile.squad)
	new_config.enemy_squad = SquadPicker.random_squad(10)
	new_config.difficulty  = config.difficulty
	Engine.set_meta("match_config", new_config)
	get_tree().change_scene_to_file("res://scenes/battle/match_view.tscn")

func _on_go_to_menu() -> void:
	AudioManager.play_sfx(&"ui_click")
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")

# ── Coordinate helpers ────────────────────────────────────────────────────────

func grid_to_screen(g: Vector2i, h: int = 0) -> Vector2:
	return Vector2(
		(g.x - g.y) * TILE_W * 0.5,
		(g.x + g.y) * TILE_H * 0.5 - h * ELEV_LIFT
	)

func screen_to_grid(s: Vector2) -> Vector2i:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	return Vector2i(roundi((s.x / hw + s.y / hh) * 0.5),
					roundi((s.y / hh - s.x / hw) * 0.5))

# ── Board construction ────────────────────────────────────────────────────────

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.06, 0.02)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

func _build_board(map: MapData = null) -> void:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	var diamond := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)
	])

	if map == null:
		# Fallback: draw flat colored polygons
		for y in match_state.board.height:
			for x in match_state.board.width:
				var g    := Vector2i(x, y)
				var poly := Polygon2D.new()
				poly.polygon  = diamond
				poly.position = grid_to_screen(g)
				poly.color    = Color(0.30, 0.40, 0.20) if (x+y)%2==0 else Color(0.20, 0.28, 0.13)
				add_child(poly)
				_tiles[g] = poly
		_active_highlight          = Polygon2D.new()
		_active_highlight.polygon  = diamond
		_active_highlight.color    = Color(1.0, 0.90, 0.20, 0.60)
		_active_highlight.z_index  = 100
		_active_highlight.visible  = false
		add_child(_active_highlight)
		_hover_poly         = Polygon2D.new()
		_hover_poly.polygon = diamond
		_hover_poly.color   = Color(1.0, 1.0, 1.0, 0.22)
		_hover_poly.visible = false
		_hover_poly.z_index = 999
		add_child(_hover_poly)
		return

	var tile_tex: Texture2D = load(TileRegistry.TEXTURE_PATH)
	var scale_flat := Vector2(float(TILE_W) / 16.0, float(TILE_H) / 16.0)
	var scale_cube := Vector2(float(TILE_W) / 16.0, float(TILE_W) / 16.0)  # uniform 4×4, preserves cube aspect ratio

	for y in map.map_rows:
		for x in map.map_width:
			var g    := Vector2i(x, y)
			var tile := map.get_tile(g)
			var h    := tile.height
			var z_base: int = (x + y) * 3 + h

			# Ground sprite
			var spr := Sprite2D.new()
			spr.texture        = tile_tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.centered       = false
			spr.region_enabled = true
			if h == 0 or tile.terrain in [&"water", &"lava"]:
				spr.region_rect = TileRegistry.flat_region(tile.terrain)
				spr.scale       = scale_flat
			else:
				spr.region_rect = TileRegistry.cube_region(map.biome)
				spr.scale       = scale_cube  # uniform 4×4 preserves 3D cube look
			spr.position = grid_to_screen(g, h) - Vector2(hw, hh)
			spr.z_index  = z_base
			add_child(spr)

			# For height 2: stack a second cube sprite at h=1 to fill the gap to ground
			if h == 2:
				var ext := Sprite2D.new()
				ext.texture        = tile_tex
				ext.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ext.centered       = false
				ext.region_enabled = true
				ext.region_rect    = TileRegistry.cube_region(map.biome)
				ext.scale          = scale_cube
				ext.position = grid_to_screen(g, 1) - Vector2(hw, hh)
				ext.z_index  = (x + y) * 3 + 1
				add_child(ext)

			# Highlight overlay (transparent Polygon2D — tinted by highlight_tiles)
			var poly := Polygon2D.new()
			poly.polygon  = diamond
			poly.color    = Color(0, 0, 0, 0)
			poly.position = grid_to_screen(g, h)
			poly.z_index  = z_base + 1
			add_child(poly)
			_tiles[g] = poly

			# Decoration sprite
			if tile.decoration != &"none":
				var dec := Sprite2D.new()
				dec.texture        = tile_tex
				dec.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				dec.centered       = false
				dec.region_enabled = true
				dec.region_rect    = TileRegistry.decoration_region(tile.decoration)
				dec.scale          = scale_flat
				var dec_lift := hh + TILE_H * 0.5 if tile.decoration != &"flower" else hh + TILE_H * 0.25
				dec.position = grid_to_screen(g, h) - Vector2(hw, dec_lift)
				dec.z_index  = z_base + 2
				add_child(dec)

	# Active unit highlight
	_active_highlight          = Polygon2D.new()
	_active_highlight.polygon  = diamond
	_active_highlight.color    = Color(1.0, 0.90, 0.20, 0.60)
	_active_highlight.z_index  = 100
	_active_highlight.visible  = false
	add_child(_active_highlight)

	# Hover overlay
	_hover_poly         = Polygon2D.new()
	_hover_poly.polygon = diamond
	_hover_poly.color   = Color(1.0, 1.0, 1.0, 0.22)
	_hover_poly.visible = false
	_hover_poly.z_index = 999
	add_child(_hover_poly)

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# ── Top strip (anchored to top of screen) ────────────────────────
	var top_ctrl := Control.new()
	top_ctrl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_ctrl.offset_bottom = 72
	top_ctrl.theme = AppTheme.game_theme
	layer.add_child(top_ctrl)

	var top_bg := ColorRect.new()
	top_bg.color        = PANEL_BG
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_ctrl.add_child(top_bg)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_margin.add_theme_constant_override("margin_left",   12)
	top_margin.add_theme_constant_override("margin_right",  12)
	top_margin.add_theme_constant_override("margin_top",    8)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_ctrl.add_child(top_margin)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_row)

	_turn_label = Label.new()
	_turn_label.custom_minimum_size = Vector2(108, 0)
	_turn_label.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_turn_label.add_theme_font_size_override("font_size", 15)
	top_row.add_child(_turn_label)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 4)
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(slots_row)

	for i in INIT_SLOTS:
		var slot := Panel.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)
		slots_row.add_child(slot)
		_initiative_slots.append(slot)
		_initiative_styles.append(style)

		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex_rect)
		_initiative_textures.append(tex_rect)

	# ── Bottom panel (anchored to bottom of screen) ──────────────────
	var bot_ctrl := Control.new()
	bot_ctrl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_ctrl.offset_top = -96
	bot_ctrl.theme = AppTheme.game_theme
	layer.add_child(bot_ctrl)

	var bot_bg := ColorRect.new()
	bot_bg.color        = PANEL_BG
	bot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bot_ctrl.add_child(bot_bg)

	var bot_margin := MarginContainer.new()
	bot_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	bot_margin.add_theme_constant_override("margin_left",   16)
	bot_margin.add_theme_constant_override("margin_right",  16)
	bot_margin.add_theme_constant_override("margin_top",    12)
	bot_margin.add_theme_constant_override("margin_bottom", 12)
	bot_ctrl.add_child(bot_margin)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 10)
	bot_margin.add_child(bot_row)

	_info_label = Label.new()
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 16)
	bot_row.add_child(_info_label)

	# Action buttons — Attack / Cancel / Wait + Auto-place (deploy only)
	var btn_row_inner := HBoxContainer.new()
	btn_row_inner.add_theme_constant_override("separation", 6)
	btn_row_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bot_row.add_child(btn_row_inner)

	_attack_btn = Button.new()
	_attack_btn.text                = "Attack"
	_attack_btn.visible             = false
	_attack_btn.custom_minimum_size = Vector2(90, 0)
	_attack_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attack_btn.pressed.connect(_on_attack)
	btn_row_inner.add_child(_attack_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text                = "Cancel"
	_cancel_btn.visible             = false
	_cancel_btn.custom_minimum_size = Vector2(90, 0)
	_cancel_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cancel_btn.pressed.connect(_on_cancel)
	btn_row_inner.add_child(_cancel_btn)

	_wait_btn = Button.new()
	_wait_btn.text                = "Wait"
	_wait_btn.custom_minimum_size = Vector2(90, 0)
	_wait_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wait_btn.pressed.connect(_on_wait)
	btn_row_inner.add_child(_wait_btn)

	_auto_btn = Button.new()
	_auto_btn.text                = "Auto-place"
	_auto_btn.visible             = false
	_auto_btn.custom_minimum_size = Vector2(110, 0)
	_auto_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_auto_btn.pressed.connect(_on_auto_place)
	btn_row_inner.add_child(_auto_btn)

func _update_initiative_strip() -> void:
	if match_state.active_unit == null:
		for i in _initiative_slots.size():
			_initiative_slots[i].visible = false
		return
	var queue: Array[BattleUnit] = match_state.peek_initiative(INIT_SLOTS)
	for i in _initiative_slots.size():
		if i < queue.size():
			var u: BattleUnit = queue[i]
			_initiative_slots[i].visible = true
			var base_a: float = 0.90 if i == 0 else 0.50
			if u.team == 0:
				_initiative_styles[i].bg_color = Color(0.22, 0.42, 0.88, base_a)
			else:
				_initiative_styles[i].bg_color = Color(0.80, 0.25, 0.25, base_a)
			var frames: SpriteFrames = load("res://resources/units/%s.tres" % u.data.sprite_stem())
			var anim: StringName = &"idle_front" if frames.has_animation(&"idle_front") else frames.get_animation_names()[0]
			_initiative_textures[i].texture = frames.get_frame_texture(anim, 0)
		else:
			_initiative_slots[i].visible = false

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(match_state.board.width >> 1, match_state.board.height >> 1))
	cam.zoom     = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()
