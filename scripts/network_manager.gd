extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()

const MAX_PLAYERS = 4
const DEFAULT_PORT = 7777
# Set to a deployed relay URL to enable cross-NAT online play.
# Format expected by relay: wss://host/?code=XXXXXX&role=host|client
const RELAY_URL := ""

var players: Dictionary = {}
var _character_selections: Dictionary = {}  # peer_id -> character_index

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---- Connection ----

func host_game(character_index: int = 0) -> String:
	var code := _generate_room_code()
	_character_selections[1] = character_index
	if not RELAY_URL.is_empty():
		var peer := WebSocketMultiplayerPeer.new()
		peer.create_client("%s?code=%s&role=host" % [RELAY_URL, code])
		multiplayer.multiplayer_peer = peer
	else:
		var peer := ENetMultiplayerPeer.new()
		peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
		multiplayer.multiplayer_peer = peer
	players[1] = {"id": 1, "ready": false}
	return code

func join_game(address: String, character_index: int = 0) -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	_character_selections[my_id] = character_index
	if not RELAY_URL.is_empty():
		var peer := WebSocketMultiplayerPeer.new()
		peer.create_client("%s?code=%s&role=client" % [RELAY_URL, address])
		multiplayer.multiplayer_peer = peer
	else:
		var peer := ENetMultiplayerPeer.new()
		peer.create_client(address, DEFAULT_PORT)
		multiplayer.multiplayer_peer = peer

func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	_character_selections.clear()

func get_player_count() -> int:
	return max(players.size(), 1)

func is_solo() -> bool:
	return not multiplayer.has_multiplayer_peer()

func get_character_selection(peer_id: int) -> int:
	return _character_selections.get(peer_id, 0)

func set_character_selection(peer_id: int, index: int) -> void:
	_character_selections[peer_id] = index

# ---- Peer events ----

func _on_peer_connected(id: int) -> void:
	players[id] = {"id": id, "ready": false}
	player_connected.emit(id)
	if multiplayer.is_server():
		_broadcast_character_selections.rpc_id(id, _character_selections)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_character_selections.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	players[my_id] = {"id": my_id, "ready": false}

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
	players.clear()
	_character_selections.clear()

# ---- Character selection sync ----

@rpc("authority", "reliable")
func _broadcast_character_selections(selections: Dictionary) -> void:
	_character_selections.merge(selections, true)

@rpc("any_peer", "reliable")
func _submit_character_selection(index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	_character_selections[sender] = index

# ---- Helpers ----

func _generate_room_code() -> String:
	const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 6:
		code += CHARS[randi() % CHARS.length()]
	return code
