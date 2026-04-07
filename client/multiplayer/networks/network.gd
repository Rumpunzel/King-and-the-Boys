@abstract
class_name Network
extends RefCounted

@abstract func create_multiplayer_server(port: int, max_connections: int) -> MultiplayerPeer
@abstract func create_multiplayer_client(ip_address: StringName, port: int) -> MultiplayerPeer
