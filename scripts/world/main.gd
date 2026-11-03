extends Node3D

@onready var player: FPSPlayer = $Player
@onready var rifle: AutomaticRifle = $Player/CameraPivot/AutomaticRifle
@onready var hud: RangeHUD = $RangeHUD
@onready var setup_panel: PanelContainer = $RangeHUD/SetupPanel
@onready var module_on_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOn
@onready var module_off_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOff
@onready var restart_button: Button = $RangeHUD/DefeatPanel/Center/VBox/Restart
@onready var wave_controller: WaveController = $WaveController

var _run_finished := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.bind_player(player)
	hud.bind_wave_controller(wave_controller)
	module_on_button.pressed.connect(_select_module.bind(true))
	module_off_button.pressed.connect(_select_module.bind(false))
	restart_button.pressed.connect(_restart_test)
	player.defeated.connect(_on_player_defeated)
	setup_panel.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("spawn_enemy") and not setup_panel.visible and not hud.is_defeat_visible():
		_spawn_enemy()

func _select_module(enabled: bool) -> void:
	rifle.setup(WeaponConfig.for_module(enabled))
	hud.bind_weapon(rifle)
	setup_panel.hide()
	player.start_control()
	wave_controller.start()

func _spawn_enemy() -> void:
	wave_controller.spawn_test_enemy()

func _on_player_defeated() -> void:
	if _run_finished:
		return
	_run_finished = true
	wave_controller.stop()
	hud.show_results(wave_controller.current_wave, wave_controller.total_kills, wave_controller.survival_time)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restart_test() -> void:
	get_tree().reload_current_scene()
