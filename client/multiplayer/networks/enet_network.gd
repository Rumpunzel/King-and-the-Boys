class_name ENetNetwork
extends Network

func create_multiplayer_server(port: int, max_connections: int) -> ENetMultiplayerPeer:
	var server_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = server_peer.create_server(port, max_connections)
	assert(error == Error.OK)
	return server_peer

func create_multiplayer_client(ip_address: StringName, port: int) -> ENetMultiplayerPeer:
	# TODO: check if hosts exists
	assert(ip_address.is_valid_ip_address())
	var client_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = client_peer.create_client(ip_address, port)
	assert(error == Error.OK)
	return client_peer
