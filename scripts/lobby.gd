extends Control

const PLAYER_COLORS: Array[String] = ["Blue", "Red", "Green", "Grey"]
const CHARACTER_TINTS: Array[Color] = [
	Color(0.4, 0.6, 1.0),
	Color(1.0, 0.4, 0.4),
	Color(0.4, 1.0, 0.5),
	Color(0.7, 0.7, 0.7),
]

var _selected_character: int = 0

@onready var room_code_label: Label = $VBox/RoomCodeLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var code_input: LineEdit = $VBox/CodeInput
@onready var start_button: Button = $VBox/StartButton
@onready var solo_button: Button = $VBox/SoloButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var char_row: HBoxContainer = $VBox/CharacterRow

func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	start_button.visible = false
	_build_character_row()

func _build_character_row() -> void:
	for c: Node in char_row.get_children():
		c.queue_free()
	for i: int in PLAYER_COLORS.size():
		var btn := Button.new()
		btn.text = PLAYER_COLORS[i]
		btn.modulate = CHARACTER_TINTS[i]
		btn.pressed.connect(_on_character_selected.bind(i))
		char_row.add_child(btn)
	_highlight_character(_selected_character)

func _highlight_character(index: int) -> void:
	var btns: Array[Node] = char_row.get_children()
	for i: int in btns.size():
		(btns[i] as Button).flat = (i != index)

func _on_character_selected(index: int) -> void:
	_selected_character = index
	_highlight_character(index)

func _on_host_pressed() -> void:
	var code: String = NetworkManager.host_game(_selected_character)
	room_code_label.text = "Room Code: %s" % code
	status_label.text = "Waiting for players…"
	start_button.visible = true
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true
	_refresh_list()

func _on_join_pressed() -> void:
	var addr: String = code_input.text.strip_edges()
	if addr.is_empty():
		return
	status_label.text = "Connecting…"
	NetworkManager.join_game(addr, _selected_character)
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true

func _on_solo_pressed() -> void:
	MetaManager.selected_character = _selected_character
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")

func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	_start_game.rpc()

func _on_player_connected(_id: int) -> void:
	_refresh_list()
	status_label.text = "%d player(s) in room" % NetworkManager.get_player_count()

func _on_player_disconnected(_id: int) -> void:
	_refresh_list()

func _on_connection_failed() -> void:
	status_label.text = "Connection failed."
	_reset_buttons()

func _on_server_disconnected() -> void:
	status_label.text = "Disconnected."
	_reset_buttons()
	NetworkManager.disconnect_game()

func _reset_buttons() -> void:
	host_button.disabled = false
	join_button.disabled = false
	solo_button.disabled = false
	start_button.visible = false

func _refresh_list() -> void:
	for child: Node in player_list.get_children():
		child.queue_free()
	var i: int = 0
	for peer_id: int in NetworkManager.players:
		var char_idx: int = NetworkManager.get_character_selection(peer_id)
		var lbl := Label.new()
		lbl.text = "Player %d — %s" % [i + 1, PLAYER_COLORS[char_idx]]
		lbl.modulate = CHARACTER_TINTS[char_idx]
		player_list.add_child(lbl)
		i += 1

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")
