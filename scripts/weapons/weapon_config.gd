class_name WeaponConfig
extends Resource
## Per-weapon tuning. The recoil module is intentionally local to this rifle configuration.

@export var recoil_module_enabled: bool = false
@export_category("Magazine")
@export var magazine_size: int = 30
@export var reserve_ammo: int = 120
@export var reload_time: float = 1.8
@export_category("Fire")
@export var rounds_per_minute: float = 600.0
@export var damage: float = 18.0
@export var range: float = 100.0
@export_category("Recoil")
@export var recoil_pitch: float = 0.55
@export var recoil_yaw: float = 0.12
@export var recovery_speed: float = 8.0

static func for_module(enabled: bool) -> WeaponConfig:
	var config := WeaponConfig.new()
	config.recoil_module_enabled = enabled
	if enabled:
		config.damage = 30.0
		config.recoil_pitch = 1.15
		config.recoil_yaw = 0.24
		config.reload_time = 2.1
	else:
		config.damage = 18.0
		config.recoil_pitch = 0.55
		config.recoil_yaw = 0.12
		config.reload_time = 1.8
	return config
