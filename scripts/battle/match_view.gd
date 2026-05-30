# scripts/battle/match_view.gd
extends Node2D

## State machine host for a single match.

const TILE_W      := 64
const TILE_H      := 32
const BOARD_W     := 7
const BOARD_H     := 7
const UNIT_SCALE  := 3.0
const SPRITE_LIFT := 8.0
const BAR_W       := 18.0
const BAR_H       := 2.5
const BAR_LIFT    := SPRITE_LIFT + 28.0

const COLOR_LIGHT   := Color(0.38, 0.47, 0.25)
const COLOR_DARK    := Color(0.26, 0.33, 0.17)
const COLOR_MOVE    := Color(0.30, 0.55, 0.95, 0.25)
const COLOR_ATTACK  := Color(0.90, 0.30, 0.30, 0.55)
const COLOR_ABILITY := Color(0.95, 0.85, 0.20, 0.55)

const PANEL_BG      := Color(0.08, 0.04, 0.01, 0.92)
const INIT_SLOTS    := 7

## Public — states read these directly.
var match_state: MatchState
var config:      MatchConfig

## Private rendering.
var _tiles:      Dictionary = {}   # Vector2i -> Polygon2D
var _sprites:    Dictionary = {}   # BattleUnit -> AnimatedSprite2D
var _idle_anims: Dictionary = {}   # BattleUnit -> StringName
var _hp_bars:    Dictionary = {}   # BattleUnit -> {bg: Polygon2D, fill: Polygon2D}

## State machine.
var _current_state: BaseBattleState = null

## UI nodes.
var _turn_label:          Label
var _info_label:          Label
var _wait_btn:            Button
var _auto_btn:            Button
var _cancel_btn:          Button
var _initiative_slots:    Array[Panel]         = []
var _initiative_styles:   Array[StyleBoxFlat]  = []
var _initiative_labels:   Array[Label]         = []
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

	match_state = MatchState.new(Board.new(BOARD_W, BOARD_H))
	_build_background()
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
	spr.position = grid_to_screen(pos) - Vector2(0, SPRITE_LIFT)
	spr.z_index  = pos.x + pos.y
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
			var screen_pos := grid_to_screen(u.grid_pos)
			spr.position = screen_pos - Vector2(0, SPRITE_LIFT)
			spr.z_index  = u.grid_pos.x + u.grid_pos.y
			if not spr.is_playing():
				spr.play(_idle_anims.get(u, &"idle_front"))
			if _hp_bars.has(u):
				var bar_pos := screen_pos - Vector2(0, BAR_LIFT)
				var z: int = u.grid_pos.x + u.grid_pos.y + 1
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

func show_cancel_btn(show: bool) -> void:
	if _cancel_btn != null:
		_cancel_btn.visible = show

func _create_hp_bar(unit: BattleUnit, pos: Vector2i) -> void:
	var bar_pos := grid_to_screen(pos) - Vector2(0, BAR_LIFT)
	var z       := pos.x + pos.y + 1
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

func set_labels(turn: String, _result: String, info: String) -> void:
	_turn_label.text = turn
	_info_label.text = info

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

func _on_cancel_move() -> void:
	if _current_state is PlayerTurnState:
		(_current_state as PlayerTurnState).on_cancel_move(self)

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

func grid_to_screen(g: Vector2i) -> Vector2:
	return Vector2((g.x - g.y) * TILE_W * 0.5, (g.x + g.y) * TILE_H * 0.5)

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

	# ── Top initiative strip ─────────────────────────────────────────
	var top_panel := ColorRect.new()
	top_panel.color       = PANEL_BG
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.position    = Vector2(0, 0)
	top_panel.size        = Vector2(540, 72)
	layer.add_child(top_panel)

	_turn_label = Label.new()
	_turn_label.position = Vector2(10, 8)
	_turn_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_turn_label)

	var slot_w: float = 64.0
	var slot_h: float = 48.0
	var slot_y: float = 12.0
	var slot_start_x: float = 120.0
	for i in INIT_SLOTS:
		var slot := Panel.new()
		slot.size         = Vector2(slot_w - 4, slot_h)
		slot.position     = Vector2(slot_start_x + i * slot_w, slot_y)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)
		layer.add_child(slot)
		_initiative_slots.append(slot)
		_initiative_styles.append(style)

		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		slot.add_child(lbl)
		_initiative_labels.append(lbl)

	# ── Bottom action panel ──────────────────────────────────────────
	var bot_panel := ColorRect.new()
	bot_panel.color        = PANEL_BG
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_panel.position     = Vector2(0, 860)
	bot_panel.size         = Vector2(540, 100)
	layer.add_child(bot_panel)

	_info_label = Label.new()
	_info_label.position = Vector2(10, 872)
	_info_label.size     = Vector2(310, 76)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_info_label)

	_wait_btn = Button.new()
	_wait_btn.text     = "Wait"
	_wait_btn.position = Vector2(400, 878)
	_wait_btn.size     = Vector2(128, 50)
	_wait_btn.pressed.connect(_on_wait)
	layer.add_child(_wait_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text    = "Cancel Move"
	_cancel_btn.visible = false
	_cancel_btn.position = Vector2(400, 878)
	_cancel_btn.size     = Vector2(128, 50)
	_cancel_btn.pressed.connect(_on_cancel_move)
	layer.add_child(_cancel_btn)

	_auto_btn = Button.new()
	_auto_btn.text     = "Auto-place"
	_auto_btn.position = Vector2(400, 878)
	_auto_btn.size     = Vector2(128, 50)
	_auto_btn.pressed.connect(_on_auto_place)
	layer.add_child(_auto_btn)

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
			var base_a: float = 0.85 if i == 0 else 0.5
			if u.team == 0:
				_initiative_styles[i].bg_color = Color(0.22, 0.42, 0.88, base_a)
			else:
				_initiative_styles[i].bg_color = Color(0.80, 0.25, 0.25, base_a)
			# Show first 6 chars of name; add "★" for the active unit.
			var n: String = u.data.display_name
			_initiative_labels[i].text = ("★\n" if i == 0 else "") + n.substr(0, 6)
		else:
			_initiative_slots[i].visible = false

func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.position = grid_to_screen(Vector2i(BOARD_W >> 1, BOARD_H >> 1))
	cam.zoom     = Vector2(1.0, 1.0)
	add_child(cam)
	cam.make_current()
