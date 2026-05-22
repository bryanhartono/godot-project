extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()

const MAX_PLAYERS = 4
const DEFAULT_PORT = 7777

var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game() -> String:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	players[1] = {"id": 1, "ready": false}
	return _generate_room_code()

func join_game(address: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, DEFAULT_PORT)
	multiplayer.multiplayer_peer = peer

func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()

func get_player_count() -> int:
	return max(players.size(), 1)

func is_solo() -> bool:
	return not multiplayer.has_multiplayer_peer()

func _generate_room_code() -> String:
	const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in 6:
		code += CHARS[randi() % CHARS.length()]
	return code

func _on_peer_connected(id: int) -> void:
	players[id] = {"id": id, "ready": false}
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	players[multiplayer.get_unique_id()] = {"id": multiplayer.get_unique_id(), "ready": false}

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
	players.clear()
