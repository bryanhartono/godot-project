# scripts/battle/states/deploy_state.gd
class_name DeployState
extends BaseBattleState

const PLAYER_ROWS: Array[int] = [5, 6]

var _unplaced: Array[MonsterData] = []

func enter(ctx: Node) -> void:
	ctx.set_deploy_mode(true)
	_unplaced = ctx.config.player_squad.duplicate()
	_place_ai_squad(ctx)
	_highlight_valid_tiles(ctx)
	ctx.set_labels("Deploy", "", "Drag a unit card to the board")
	ctx.show_unit_cards(_unplaced)

func exit(ctx: Node) -> void:
	ctx.set_deploy_mode(false)
	ctx.hide_unit_cards()
	ctx.clear_highlights()

func handle_input(_ctx: Node, _event: InputEvent) -> void:
	pass  # Placement handled via card drag in match_view

## Called by match_view when the player drops a card over the board.
func on_card_dropped(ctx: Node, data: MonsterData, tile: Vector2i) -> void:
	if not (data in _unplaced):
		return
	if not _is_valid_tile(ctx, tile):
		return
	_unplaced.erase(data)
	ctx.spawn_unit(data, 0, tile)
	ctx.remove_unit_card(data)
	AudioManager.play_sfx(&"place_unit")
	_highlight_valid_tiles(ctx)
	if _unplaced.is_empty():
		ctx.clear_highlights()
		ctx.match_state.initialize_initiative()
		ctx.advance_turn()

## Auto-place all remaining units on random valid tiles.
func auto_place(ctx: Node) -> void:
	var valid: Array[Vector2i] = []
	for y in PLAYER_ROWS:
		for x in range(ctx.match_state.board.width):
			var g := Vector2i(x, y)
			if not ctx.match_state.board.is_occupied(g):
				valid.append(g)
	valid.shuffle()
	var placed := 0
	while not _unplaced.is_empty() and placed < valid.size():
		var data := _unplaced.pop_front() as MonsterData
		ctx.spawn_unit(data, 0, valid[placed])
		placed += 1
	ctx.hide_unit_cards()
	ctx.clear_highlights()
	ctx.match_state.initialize_initiative()
	ctx.advance_turn()

# ── Internal ──────────────────────────────────────────────────────────────────

func _place_ai_squad(ctx: Node) -> void:
	var ai_squad: Array[MonsterData] = ctx.config.enemy_squad
	var positions := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	                  Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	for i in range(mini(ai_squad.size(), positions.size())):
		ctx.spawn_unit(ai_squad[i], 1, positions[i])

func _is_valid_tile(ctx: Node, g: Vector2i) -> bool:
	if not ctx.match_state.board.is_in_bounds(g):
		return false
	if ctx.match_state.board.is_occupied(g):
		return false
	if g.y not in PLAYER_ROWS:
		return false
	return true

func _highlight_valid_tiles(ctx: Node) -> void:
	var valid: Array[Vector2i] = []
	for y in PLAYER_ROWS:
		for x in range(ctx.match_state.board.width):
			var g := Vector2i(x, y)
			if not ctx.match_state.board.is_occupied(g):
				valid.append(g)
	ctx.highlight_tiles(valid, ([] as Array[BattleUnit]), ([] as Array[Vector2i]))
