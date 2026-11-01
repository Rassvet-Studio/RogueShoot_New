extends Node3D

@onready var player: FPSPlayer = $Player
@onready var rifle: AutomaticRifle = $Player/CameraPivot/AutomaticRifle
@onready var hud: RangeHUD = $RangeHUD
@onready var setup_panel: PanelContainer = $RangeHUD/SetupPanel
@onready var module_on_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOn
@onready var module_off_button: Button = $RangeHUD/SetupPanel/Center/VBox/ModuleOff

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.bind_player(player)
	module_on_button.pressed.connect(_select_module.bind(true))
	module_off_button.pressed.connect(_select_module.bind(false))
	setup_panel.show()

func _select_module(enabled: bool) -> void:
	rifle.setup(WeaponConfig.for_module(enabled))
	hud.bind_weapon(rifle)
	setup_panel.hide()
	player.start_control()
