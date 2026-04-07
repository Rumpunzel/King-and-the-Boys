class_name SteamNetwork
extends Network

func create_multiplayer_server(port: int, max_connections: int) -> SteamMultiplayerPeer:
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, max_connections + 1)
	var server_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	#var error: Error = server_peer.host_with_lobby()
	#assert(error == Error.OK)
	return server_peer

func create_multiplayer_client(ip_address: StringName, port: int) -> SteamMultiplayerPeer:
	# TODO: check if hosts exists
	assert(ip_address.is_valid_ip_address())
	var client_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
	var error: Error = client_peer.create_client(1, port)
	assert(error == Error.OK)
	return client_peer
