extends Node3D

@onready var player: FPSPlayer = $Player
@onready var rifle: AutomaticRifle = $Player/CameraPivot/AutomaticRifle
@onready var hud: RangeHUD = $RangeHUD
@onready var setup_panel: PanelContainer = $RangeHUD/SetupPanel
@onready var module_on_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOn
@onready var module_off_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOff
@onready var restart_button: Button = $RangeHUD/DefeatPanel/Center/VBox/Restart
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/melee_enemy.tscn")

var _spawn_index := 0
var _enemy_spawn_points := [Vector3(-8, 0.1, -8), Vector3(8, 0.1, -8), Vector3(0, 0.1, -11)]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.bind_player(player)
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

func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = _enemy_spawn_points[_spawn_index % _enemy_spawn_points.size()]
	_spawn_index += 1

func _on_player_defeated() -> void:
	hud.show_defeat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _restart_test() -> void:
	get_tree().reload_current_scene()
