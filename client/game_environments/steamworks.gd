@icon("uid://dhn3vkdxvetbn")
class_name Steamworks
extends GameEnvironment

## Emitted when Steam loaded the avatar of the user with [param steam_id]
signal avatar_loaded(steam_id: int, avatar_texture: ImageTexture)

var _is_initialized: bool = false

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	Steam.run_callbacks()

## @returns the Steam name of the player with the multiplayer id [param player_id], empty if unknown
func get_player_name(player_id: int) -> String:
	var steam_id: int = _get_steam_id(player_id)
	if steam_id == 0: return ""
	if steam_id == Steam.getSteamID(): return Steam.getPersonaName()
	return Steam.getFriendPersonaName(steam_id)

## @returns the Steam avatar of the player with the multiplayer id [param player_id], null if unknown
func get_player_avatar(player_id: int) -> Texture2D:
	var steam_id: int = _get_steam_id(player_id)
	if steam_id == 0: return null
	Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, steam_id)
	# Avatars of several players may be loading at once: wait for this player's
	while true:
		var loaded: Array = await avatar_loaded
		var loaded_steam_id: int = loaded[0]
		if loaded_steam_id != steam_id: continue
		var avatar_texture: ImageTexture = loaded[1]
		return avatar_texture
	return null

## @returns the Steam id of the player with the multiplayer id [param player_id]: the local user's own, or the one
## the Steam multiplayer peer knows; [code]0[/code] without Steam or over another network (e.g. ENet)
func _get_steam_id(player_id: int) -> int:
	if not _is_initialized: return 0
	if not Multiplayer.is_online() or player_id == multiplayer.get_unique_id(): return Steam.getSteamID()
	var steam_peer: SteamMultiplayerPeer = multiplayer.multiplayer_peer as SteamMultiplayerPeer
	if not steam_peer: return 0
	return steam_peer.get_steam_id_for_peer_id(player_id)

func _initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, disabling Steam functionality: %s" % initialize_response)
		# Again, show some kind of prompt informing the player certain functions are missing
		return
	print("Steam user name: %s" % Steam.getPersonaName())
	_is_initialized = true
	Steam.avatar_loaded.connect(_on_avatar_loaded)

func _set_rich_presence(token: String) -> void:
	var setting_presence: bool = Steam.setRichPresence("steam_display", token)
	print("Setting rich presence to %s: %s" % [token, setting_presence])

func _on_game_quit() -> void: pass

func _on_avatar_loaded(steam_id: int, size: int, data: PackedByteArray) -> void:
	var avatar_image: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit(steam_id, avatar_texture)
