extends Control

const PLAYER_COLORS := ["Blue", "Red", "Green", "Grey"]

@onready var room_code_label: Label = $VBox/RoomCodeLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var code_input: LineEdit = $VBox/CodeInput
@onready var start_button: Button = $VBox/StartButton
@onready var solo_button: Button = $VBox/SoloButton
@onready var status_label: Label = $VBox/StatusLabel

func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	start_button.visible = false

func _on_host_pressed() -> void:
	var code := NetworkManager.host_game()
	room_code_label.text = "Room Code: %s" % code
	status_label.text = "Waiting for players…"
	start_button.visible = true
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true
	_refresh_list()

func _on_join_pressed() -> void:
	var addr := code_input.text.strip_edges()
	if addr.is_empty():
		return
	status_label.text = "Connecting…"
	NetworkManager.join_game(addr)
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true

func _on_solo_pressed() -> void:
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
	for child in player_list.get_children():
		child.queue_free()
	var i := 0
	for _peer_id in NetworkManager.players:
		var lbl := Label.new()
		lbl.text = "Player %d — %s" % [i + 1, PLAYER_COLORS[i % 4]]
		player_list.add_child(lbl)
		i += 1

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")
