class_name SettingsManager
extends Node
## Local-only persistent settings. No values are sent through multiplayer RPC.

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MOUSE_SENSITIVITY := 0.12
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_FULLSCREEN := false

var mouse_sensitivity := DEFAULT_MOUSE_SENSITIVITY
var master_volume := DEFAULT_MASTER_VOLUME
var fullscreen := DEFAULT_FULLSCREEN

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		reset_defaults(false)
		return
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), 0.04, 0.3)
	master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN))
	_apply_audio()
	_apply_window_mode()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Не удалось сохранить настройки: %s" % error_string(error))

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.04, 0.3)
	save_settings()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window_mode()
	save_settings()

func reset_defaults(persist: bool = true) -> void:
	mouse_sensitivity = DEFAULT_MOUSE_SENSITIVITY
	master_volume = DEFAULT_MASTER_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	_apply_audio()
	_apply_window_mode()
	if persist:
		save_settings()

func _apply_audio() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))

func _apply_window_mode() -> void:
	if not is_inside_tree():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
