@tool
@icon("uid://djyg1pu0yqd4c")
extends Node

signal game_hosted(ip_address: StringName, port: int)
signal game_joined(host_player_info: Dictionary[StringName, Variant])
signal player_joined(player_info: Dictionary[StringName, Variant])

signal joining_multiplayer
signal connected_to_multiplayer
signal disconnected_from_multiplayer

enum {
	NONE,
	SERVER,
	CLIENT,
}

const PORT: int = 7000
const DEFAULT_SERVER_IP: StringName = "127.0.0.1" # IPv4 localhost
const MAX_CONNECTIONS: int = 4
const HOST_ID: int = 1

@onready var _network: Network = ENetNetwork.new()

func _enter_tree() -> void:
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _ready() -> void:
	_go_offline()

func host_game(ip_address: StringName = DEFAULT_SERVER_IP, port: int = PORT) -> Error:
	assert(_network)
	multiplayer.multiplayer_peer = _network.create_multiplayer_server(port, MAX_CONNECTIONS)
	game_hosted.emit(ip_address, port)
	connected_to_multiplayer.emit()
	print_debug("Started hosting multiplayer game @ %s:%d!" % [ip_address, port])
	add_child(Node.new()) # For debugging to make it clear who is host
	return Error.OK

func join_game(ip_address: StringName, port: int = PORT) -> Error:
	# TODO: check if hosts exists
	assert(ip_address.is_valid_ip_address())
	joining_multiplayer.emit()
	assert(_network)
	multiplayer.multiplayer_peer = _network.create_multiplayer_client(ip_address, port)
	connected_to_multiplayer.emit()
	print_debug("Joined multiplayer game @ %s:%d!" % [ip_address, port])
	return Error.OK

func stop_hosting_game() -> void:
	assert(is_online())
	_go_offline()
	print_debug("Stopped hosting multiplayer game!")

func leave_game() -> void:
	assert(is_online())
	_go_offline()
	print_debug("Left multiplayer game!")

func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

@rpc("any_peer", "reliable")
func _register_player(player_info: Dictionary[StringName, Variant]) -> void:
	Player.validate_player_info(player_info)
	var peer_id: int = multiplayer.get_remote_sender_id() if is_online() else HOST_ID
	player_info[Player.ID] = peer_id
	if peer_id == HOST_ID:
		game_joined.emit(player_info)
		connected_to_multiplayer.emit()
		print_debug("Joined Player %s's multiplayer game!" % player_info)
	else:
		player_joined.emit(player_info)
		print_debug("Player %s joined multiplayer game!" % player_info)

func _go_offline() -> void:
	var offline_peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = offline_peer
	disconnected_from_multiplayer.emit()

## When a peer connects, send them the host info.
## This allows transfer of all desired data for each player, not only the unique ID.
func _on_player_connected(peer_id: int) -> void:
	var host_player_info: Dictionary[StringName, Variant] = Player.get_local_player_info()
	_register_player.rpc_id(peer_id, host_player_info)

func _on_connected_to_server() -> void:
	print_debug("Connected to multiplayer server!")

func _on_connection_failed() -> void:
	_go_offline()
	print_debug("Connection failed!")

func _on_server_disconnected() -> void:
	_go_offline()
	print_debug("Server disconnected!")
