extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed()
signal server_disconnected()

const MAX_PLAYERS: int = 4
const DEFAULT_PORT: int = 7777
# Set to a deployed relay URL to enable cross-NAT online play.
# Format: wss://host/?code=XXXXXX&role=host|client
const RELAY_URL: String = ""

var players: Dictionary = {}
var _character_selections: Dictionary = {}
var _pending_char_selection: int = 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---- Connection ----

func host_game(character_index: int = 0) -> String:
	var code: String = _generate_room_code()
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
	_pending_char_selection = character_index
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
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func get_character_selection(peer_id: int) -> int:
	return _character_selections.get(peer_id, 0)

# ---- Peer events ----

func _on_peer_connected(id: int) -> void:
	players[id] = {"id": id, "ready": false}
	player_connected.emit(id)
	if multiplayer.is_server():
		# Send existing selections to the newly joined peer
		_broadcast_character_selections.rpc_id(id, _character_selections)

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_character_selections.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var my_id: int = multiplayer.get_unique_id()
	players[my_id] = {"id": my_id, "ready": false}
	_character_selections[my_id] = _pending_char_selection
	# Announce our character selection to the server
	_submit_character_selection.rpc_id(1, _pending_char_selection)

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
	var sender: int = multiplayer.get_remote_sender_id()
	_character_selections[sender] = index

# ---- Helpers ----

func _generate_room_code() -> String:
	const CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code: String = ""
	for i: int in 6:
		code += CHARS[randi() % CHARS.length()]
	return code
