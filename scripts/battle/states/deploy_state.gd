# scripts/battle/states/deploy_state.gd
class_name DeployState
extends BaseBattleState

## Rows available for player placement (y = 5 and y = 6 on a 7×7 board).
const PLAYER_ROWS: Array[int] = [5, 6]

var _queue: Array[MonsterData] = []

func enter(ctx: Node) -> void:
	_queue = ctx.config.player_squad.duplicate()
	_place_ai_squad(ctx)
	_highlight_valid_tiles(ctx)
	_update_label(ctx)

func exit(ctx: Node) -> void:
	ctx.clear_highlights()

func handle_input(ctx: Node, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var g: Vector2i = ctx.screen_to_grid(ctx.get_local_mouse_position())
	_try_place(ctx, g)

# ── Internal ──────────────────────────────────────────────────────────────────

func _place_ai_squad(ctx: Node) -> void:
	var ai_squad: Array[MonsterData] = ctx.config.enemy_squad
	var positions := [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	                  Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	for i in range(mini(ai_squad.size(), positions.size())):
		ctx.spawn_unit(ai_squad[i], 1, positions[i])

func _try_place(ctx: Node, g: Vector2i) -> void:
	if _queue.is_empty():
		return
	if not _is_valid_tile(ctx, g):
		return
	var data := _queue.pop_front() as MonsterData
	ctx.spawn_unit(data, 0, g)
	_highlight_valid_tiles(ctx)
	_update_label(ctx)
	if _queue.is_empty():
		ctx.clear_highlights()
		ctx.change_state(PlayerTurnState.new())

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

func _update_label(ctx: Node) -> void:
	var next_name := _queue[0].display_name if not _queue.is_empty() else ""
	ctx.set_labels("Deploy: place %s" % next_name, "", "Tap a blue tile to place your unit")

## Auto-place remaining units randomly (called by Auto-place button).
func auto_place(ctx: Node) -> void:
	var valid: Array[Vector2i] = []
	for y in PLAYER_ROWS:
		for x in range(ctx.match_state.board.width):
			var g := Vector2i(x, y)
			if not ctx.match_state.board.is_occupied(g):
				valid.append(g)
	valid.shuffle()
	var placed := 0
	while not _queue.is_empty() and placed < valid.size():
		var data := _queue.pop_front() as MonsterData
		ctx.spawn_unit(data, 0, valid[placed])
		placed += 1
	ctx.clear_highlights()
	ctx.change_state(PlayerTurnState.new())
