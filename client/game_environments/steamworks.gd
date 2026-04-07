@icon("uid://dhn3vkdxvetbn")
class_name Steamworks
extends GameEnvironment

signal avatar_loaded(avatar_texture: ImageTexture)

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func get_player_name(player_id: int) -> String:
	return Steam.getPersonaName()

func get_player_avatar(player_id: int) -> Texture2D:
	Steam.getPlayerAvatar()
	var avatar_texture: ImageTexture = await avatar_loaded
	return avatar_texture

func _initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, disabling Steam functionality: %s" % initialize_response)
		# Again, show some kind of prompt informing the player certain functions are missing
		return
	print("Steam user name: %s" % Steam.getPersonaName())
	Steam.avatar_loaded.connect(_on_avatar_loaded)

func _set_rich_presence(token: String) -> void:
	var setting_presence: bool = Steam.setRichPresence("steam_display", token)
	print("Setting rich presence to %s: %s" % [token, setting_presence])

func _on_game_quit() -> void: pass

func _on_avatar_loaded(_avatar_id: int, size: int, data: PackedByteArray) -> void:
	var avatar_image: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	avatar_loaded.emit(avatar_texture)
