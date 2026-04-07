@tool
@icon("uid://cawf6uult17mx")
class_name Config
extends Node

signal config_updated(value: Variant, section: String, key: String)

enum Scope {
	USER,
	LOCAL,
}

@export var _config_file_name: String = "config"
@export var _scope: Scope = Scope.LOCAL # Scope.USER
@export_dir var _config_directory: String = "res://"

@onready var _config: ConfigFile = _load_config_file(_get_config_file_path())

func update_value_in_config(value: Variant, section: String, key: String) -> Error:
	assert(not section.is_empty())
	assert(not key.is_empty())
	assert(_config)
	_config.set_value(section, key, value)
	config_updated.emit(value, section, key)
	return _update_config_file()

func update_values_in_config(config_entries: Array[ConfigEntry]) -> Error:
	assert(not config_entries.is_empty())
	assert(_config)
	for config_entry: ConfigEntry in config_entries:
		_config.set_value(config_entry.section, config_entry.key, config_entry.value)
		config_updated.emit(config_entry.value, config_entry.section, config_entry.key)
	return _update_config_file()

func get_value_from_config(section: String, key: String, default_value: Variant = null) -> Variant:
	return _config.get_value(section, key, default_value)

func get_values_from_config(section: String, keys: Array[String], default_value: Variant = null) -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in keys:
		var value: Variant = _config.get_value(section, key, default_value)
		values[key] = value
	return values

func _update_config_file() -> Error:
	# Save it to a file (overwrite if already exists).
	var error: Error = _config.save(_get_config_file_path())
	if error == OK: print_debug("Saved config!")
	else: push_error("Could not save config file due to Error %s" % error)
	return error

func _get_config_file_path() -> String:
	var config_file_path: String
	match _scope:
		Scope.USER: config_file_path = "user://"
		Scope.LOCAL: config_file_path = _config_directory
		_: assert(false, "Match case for Scope is not exhaustive!")
	return config_file_path.path_join(_config_file_name) + ".cfg"

static func _load_config_file(config_file_path: String) -> ConfigFile:
	if not FileAccess.file_exists(config_file_path):
		print_debug("No config file found, creating default!")
		var default_error: Error = _create_default_config_file(config_file_path)
		if default_error != OK: return null
	
	var config: ConfigFile = ConfigFile.new()
	# Load data from a file.
	var error: Error = config.load(config_file_path)
	# If the file didn't load, ignore it.
	if error != OK:
		push_error("Could not load config file due to Error %s" % error)
		return null
	print_debug("Loaded config!")
	return config

static func _create_default_config_file(config_file_path: String) -> Error:
	var default_config: ConfigFile = ConfigFile.new()
	var error: Error = default_config.save(config_file_path)
	if error == OK: print_debug("Saved default config!")
	else: push_error("Could not save default config file due to Error %s" % error)
	return error

class ConfigEntry:
	var value: Variant
	var section: String
	var key: String
	func _init(new_value: Variant, new_section: String, new_key: String) -> void:
		value = new_value
		section = new_section
		key = new_key
