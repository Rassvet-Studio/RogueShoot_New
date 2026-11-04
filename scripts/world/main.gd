extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var player: FPSPlayer = $Player
@onready var rifle: AutomaticRifle = $Player/CameraPivot/AutomaticRifle
@onready var hud: RangeHUD = $RangeHUD
@onready var network_session: NetworkSession = $NetworkSession
@onready var network_panel: PanelContainer = $RangeHUD/NetworkPanel
@onready var network_single_button: Button = $RangeHUD/NetworkPanel/Center/VBox/Single
@onready var network_host_button: Button = $RangeHUD/NetworkPanel/Center/VBox/Host
@onready var network_join_button: Button = $RangeHUD/NetworkPanel/Center/VBox/Join
@onready var network_address: LineEdit = $RangeHUD/NetworkPanel/Center/VBox/Address
@onready var network_status: Label = $RangeHUD/NetworkPanel/Center/VBox/Status
@onready var settings_button: Button = $RangeHUD/NetworkPanel/Center/VBox/Settings
@onready var setup_panel: PanelContainer = $RangeHUD/SetupPanel
@onready var module_on_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOn
@onready var module_off_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOff
@onready var restart_button: Button = $RangeHUD/DefeatPanel/Center/VBox/Restart
@onready var wave_controller: WaveController = $WaveController
@onready var settings_manager: SettingsManager = $SettingsManager
@onready var settings_panel: PanelContainer = $RangeHUD/SettingsPanel
@onready var mouse_sensitivity_slider: HSlider = $RangeHUD/SettingsPanel/Margin/VBox/MouseSensitivity
@onready var mouse_value_label: Label = $RangeHUD/SettingsPanel/Margin/VBox/MouseValue
@onready var volume_slider: HSlider = $RangeHUD/SettingsPanel/Margin/VBox/MasterVolume
@onready var volume_value_label: Label = $RangeHUD/SettingsPanel/Margin/VBox/VolumeValue
@onready var fullscreen_toggle: CheckButton = $RangeHUD/SettingsPanel/Margin/VBox/Fullscreen
@onready var defaults_button: Button = $RangeHUD/SettingsPanel/Margin/VBox/Buttons/Defaults
@onready var back_button: Button = $RangeHUD/SettingsPanel/Margin/VBox/Buttons/Back

var _network_mode := "single"
var _local_peer_id := 1
var _module_enabled := false
var _run_started := false
var _run_finished := false
var _network_players: Dictionary = {}
var _dead_player_ids: Dictionary = {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.bind_player(player)
	hud.bind_wave_controller(wave_controller)
	setup_panel.hide()
	settings_panel.hide()
	network_panel.show()
	network_single_button.pressed.connect(_start_single)
	network_host_button.pressed.connect(_create_host)
	network_join_button.pressed.connect(_join_host)
	settings_button.pressed.connect(_open_settings)
	back_button.pressed.connect(_close_settings)
	defaults_button.pressed.connect(_reset_settings)
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	module_on_button.pressed.connect(_select_module.bind(true))
	module_off_button.pressed.connect(_select_module.bind(false))
	restart_button.pressed.connect(_restart_test)
	player.defeated.connect(_on_player_defeated)
	player.health.health_changed.connect(_on_local_health_changed)
	network_session.status_changed.connect(_on_network_status)
	network_session.connected_to_host.connect(_on_client_connected)
	network_session.peer_joined.connect(_on_peer_joined)
	network_session.peer_left.connect(_on_peer_left)
	network_session.server_left.connect(_on_server_left)
	wave_controller.wave_started.connect(_on_wave_started)
	wave_controller.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_controller.intermission_changed.connect(_on_intermission_changed)
	wave_controller.enemy_spawned.connect(_on_enemy_spawned)
	wave_controller.enemy_removed.connect(_on_enemy_removed)
	wave_controller.enemy_health_changed.connect(_on_enemy_health_changed)
	_refresh_settings_controls()
	_apply_local_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_enemy") and _run_started and not hud.is_defeat_visible():
		_spawn_enemy()

func _start_single() -> void:
	network_session.start_single()
	_prepare_local_mode("single", 1)

func _create_host() -> void:
	if network_session.create_host():
		_prepare_local_mode("host", network_session.local_peer_id)

func _join_host() -> void:
	network_session.join_host(network_address.text)

func _prepare_local_mode(mode: String, peer_id: int) -> void:
	_network_mode = mode
	_local_peer_id = peer_id
	if mode != "single":
		player.configure_network(peer_id, true)
	network_panel.hide()
	setup_panel.show()

func _on_client_connected() -> void:
	_local_peer_id = network_session.local_peer_id
	_network_mode = "client"
	player.configure_network(_local_peer_id, true)
	network_status.text = "Подключено. Ожидание запуска хоста..."
	network_panel.show()
	network_single_button.disabled = true
	network_host_button.disabled = true
	network_join_button.disabled = true

func _on_network_status(message: String) -> void:
	network_status.text = message

func _open_settings() -> void:
	_refresh_settings_controls()
	network_panel.hide()
	setup_panel.hide()
	settings_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_settings() -> void:
	settings_panel.hide()
	if _run_started:
		player.start_control()
	else:
		network_panel.show()

func _reset_settings() -> void:
	settings_manager.reset_defaults()
	_refresh_settings_controls()
	_apply_local_settings()

func _on_mouse_sensitivity_changed(value: float) -> void:
	settings_manager.set_mouse_sensitivity(value)
	_apply_local_settings()
	mouse_value_label.text = "%.2f" % settings_manager.mouse_sensitivity

func _on_volume_changed(value: float) -> void:
	settings_manager.set_master_volume(value)
	volume_value_label.text = "%d%%" % roundi(settings_manager.master_volume * 100.0)

func _on_fullscreen_toggled(value: bool) -> void:
	settings_manager.set_fullscreen(value)

func _refresh_settings_controls() -> void:
	mouse_sensitivity_slider.set_value_no_signal(settings_manager.mouse_sensitivity)
	mouse_value_label.text = "%.2f" % settings_manager.mouse_sensitivity
	volume_slider.set_value_no_signal(settings_manager.master_volume)
	volume_value_label.text = "%d%%" % roundi(settings_manager.master_volume * 100.0)
	fullscreen_toggle.set_pressed_no_signal(settings_manager.fullscreen)

func _apply_local_settings() -> void:
	# This is the local player instance, including a client in co-op mode.
	player.mouse_sensitivity = settings_manager.mouse_sensitivity

func _select_module(enabled: bool) -> void:
	_activate_run(enabled)
	if _network_mode == "host":
		rpc("network_start_run", enabled)

func _activate_run(enabled: bool) -> void:
	if _run_started:
		return
	_module_enabled = enabled
	_run_started = true
	rifle.setup(WeaponConfig.for_module(enabled))
	setup_panel.hide()
	network_panel.hide()
	player.start_control()
	if _network_mode != "client":
		wave_controller.start()

func _spawn_enemy() -> void:
	wave_controller.spawn_test_enemy()

func _on_player_defeated() -> void:
	if _run_finished:
		return
	_dead_player_ids[1] = true
	if _network_mode == "client":
		return
	if _network_mode == "host" and _dead_player_ids.size() < _network_players.size() + 1:
		return
	_run_finished = true
	wave_controller.stop()
	hud.show_results(wave_controller.current_wave, wave_controller.total_kills, wave_controller.survival_time)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _network_mode == "host":
		rpc("network_run_finished", wave_controller.current_wave, wave_controller.total_kills, wave_controller.survival_time)

func _restart_test() -> void:
	get_tree().reload_current_scene()

func _on_peer_joined(peer_id: int) -> void:
	if _network_mode != "host":
		return
	_ensure_network_player(peer_id)
	rpc("network_spawn_player", peer_id)
	rpc_id(peer_id, "network_spawn_player", 1)
	if _run_started:
		rpc_id(peer_id, "network_start_run", _module_enabled)
		for snapshot in wave_controller.get_network_snapshots():
			rpc_id(peer_id, "network_spawn_enemy", snapshot["id"], snapshot["position"])
			rpc_id(peer_id, "network_enemy_health", snapshot["id"], snapshot["health"], 100.0)
		rpc_id(peer_id, "network_wave_state", wave_controller.current_wave, wave_controller.alive_enemy_count, wave_controller.pending_enemy_count, wave_controller.intermission_remaining)

func _on_peer_left(peer_id: int) -> void:
	var remote: Node = _network_players.get(peer_id)
	if is_instance_valid(remote):
		remote.queue_free()
	_network_players.erase(peer_id)

func _on_server_left() -> void:
	network_panel.show()
	network_status.text = "Хост завершил игру"
	_run_started = false
	_run_finished = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ensure_network_player(peer_id: int) -> FPSPlayer:
	if peer_id == _local_peer_id:
		return player
	if _network_players.has(peer_id) and is_instance_valid(_network_players[peer_id]):
		return _network_players[peer_id]
	var remote := PLAYER_SCENE.instantiate() as FPSPlayer
	remote.name = "Player_%d" % peer_id
	remote.set_meta("network_remote", true)
	add_child(remote)
	remote.configure_network(peer_id, false)
	if _network_mode == "host" and _run_started:
		(remote.get_node("CameraPivot/AutomaticRifle") as AutomaticRifle).setup(WeaponConfig.for_module(_module_enabled))
	remote.defeated.connect(_on_remote_player_defeated.bind(peer_id))
	if _network_mode == "host":
		remote.health.health_changed.connect(_on_network_player_health_changed.bind(peer_id))
	_network_players[peer_id] = remote
	return remote

func broadcast_player_transform(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if _network_mode == "single" or not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		rpc("network_player_transform", peer_id, position, yaw, pitch)
	else:
		rpc_id(1, "network_player_transform", peer_id, position, yaw, pitch)

@rpc("any_peer", "unreliable")
func network_player_transform(peer_id: int, position: Vector3, yaw: float, pitch: float) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() != peer_id and peer_id != 1:
		return
	if multiplayer.is_server():
		rpc("network_player_transform", peer_id, position, yaw, pitch)
	var target := _ensure_network_player(peer_id)
	if target != player:
		target.apply_network_transform(position, yaw, pitch)

@rpc("authority", "call_local", "reliable")
func network_spawn_player(peer_id: int) -> void:
	_ensure_network_player(peer_id)

@rpc("authority", "reliable")
func network_start_run(enabled: bool) -> void:
	_activate_run(enabled)

func request_network_shot(origin: Vector3, direction: Vector3) -> void:
	if _network_mode == "client":
		rpc_id(1, "network_request_shot", origin, direction)

@rpc("any_peer", "reliable")
func network_request_shot(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var attacker: FPSPlayer = _network_players.get(sender)
	if attacker == null or not attacker.is_alive():
		return
	var attacker_rifle := attacker.get_node("CameraPivot/AutomaticRifle") as AutomaticRifle
	attacker_rifle._shoot_hitscan_from(origin, direction)

@rpc("authority", "reliable")
func network_run_finished(wave: int, kills: int, survival_time: float) -> void:
	if _run_finished:
		return
	_run_finished = true
	hud.show_results(wave, kills, survival_time)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_wave_started(number: int, total: int) -> void:
	_broadcast_wave_state(number, 0, total, 0.0)

func _on_enemy_count_changed(alive: int, pending: int) -> void:
	_broadcast_wave_state(wave_controller.current_wave, alive, pending, wave_controller.intermission_remaining)

func _on_intermission_changed(remaining: float) -> void:
	_broadcast_wave_state(wave_controller.current_wave, wave_controller.alive_enemy_count, wave_controller.pending_enemy_count, remaining)

func _broadcast_wave_state(number: int, alive: int, pending: int, next_wave_time: float) -> void:
	if _network_mode == "host" and is_inside_tree() and multiplayer.multiplayer_peer != null:
		rpc("network_wave_state", number, alive, pending, next_wave_time)

@rpc("authority", "unreliable")
func network_wave_state(number: int, alive: int, pending: int, next_wave_time: float) -> void:
	if _network_mode == "client":
		hud.set_wave_state(number, alive, pending, next_wave_time)

func _on_enemy_spawned(enemy_id: int, position: Vector3) -> void:
	if _network_mode == "host":
		rpc("network_spawn_enemy", enemy_id, position)

func _on_enemy_removed(enemy_id: int) -> void:
	if _network_mode == "host":
		rpc("network_remove_enemy", enemy_id)

func _on_enemy_health_changed(enemy_id: int, current: float, maximum: float) -> void:
	if _network_mode == "host":
		rpc("network_enemy_health", enemy_id, current, maximum)

@rpc("authority", "reliable")
func network_spawn_enemy(enemy_id: int, position: Vector3) -> void:
	if _network_mode == "client":
		wave_controller.spawn_network_replica(enemy_id, position)

@rpc("authority", "reliable")
func network_remove_enemy(enemy_id: int) -> void:
	if _network_mode != "client":
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if int(enemy.get_meta("network_id", -1)) == enemy_id:
			enemy.queue_free()

@rpc("authority", "unreliable")
func network_enemy_health(enemy_id: int, current: float, _maximum: float) -> void:
	if _network_mode != "client":
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if int(enemy.get_meta("network_id", -1)) == enemy_id:
			var health := enemy.get_node_or_null("Health") as HealthComponent
			if health != null:
				health.set_network_health(current)

func _on_remote_player_defeated(peer_id: int) -> void:
	_dead_player_ids[peer_id] = true
	if _network_mode == "host" and not _run_finished and _dead_player_ids.size() >= _network_players.size() + 1:
		_on_player_defeated()

func _on_local_health_changed(current: float, maximum: float) -> void:
	if _network_mode == "host":
		rpc("network_player_health", 1, current, maximum)

func _on_network_player_health_changed(current: float, maximum: float, peer_id: int) -> void:
	if _network_mode == "host":
		rpc("network_player_health", peer_id, current, maximum)

@rpc("authority", "unreliable")
func network_player_health(peer_id: int, current: float, _maximum: float) -> void:
	if _network_mode != "client":
		return
	var target := player if peer_id == _local_peer_id else _ensure_network_player(peer_id)
	target.health.set_network_health(current)
