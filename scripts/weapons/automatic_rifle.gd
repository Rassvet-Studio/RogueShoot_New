class_name AutomaticRifle
extends Node3D
## Local hitscan weapon. Ownership can later be assigned per network player without global state.

signal ammo_changed(magazine: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal hit_confirmed
signal dry_fire

@export var config: WeaponConfig
@export var camera_path: NodePath = NodePath("../../CameraPivot/Camera3D")
@export var player_path: NodePath = NodePath("../..")
@onready var camera: Camera3D = get_node(camera_path)
@onready var player: CharacterBody3D = get_node(player_path)
@onready var model: Node3D = $Model

var magazine_ammo: int
var reserve_ammo: int
var _reload_remaining := 0.0
var _shot_cooldown := 0.0
var _recoil_offset := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var is_reloading: bool:
	get:
		return _reload_remaining > 0.0

func setup(weapon_config: WeaponConfig) -> void:
	config = weapon_config
	magazine_ammo = config.magazine_size
	reserve_ammo = config.reserve_ammo
	ammo_changed.emit(magazine_ammo, reserve_ammo)

func _ready() -> void:
	_rng.randomize()
	if config == null:
		setup(WeaponConfig.for_module(false))

func _process(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta
	if is_reloading:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_finish_reload()
	_recoil_offset = _recoil_offset.move_toward(Vector3.ZERO, config.recovery_speed * delta)
	model.position = Vector3(0.34, -0.28, -0.62) + _recoil_offset

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		_start_reload()

func _physics_process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or is_reloading or (player.has_method("is_alive") and not player.is_alive()):
		return
	if Input.is_action_pressed("fire"):
		_try_fire()

func _try_fire() -> void:
	if _shot_cooldown > 0.0:
		return
	if magazine_ammo <= 0:
		dry_fire.emit()
		_start_reload()
		return
	magazine_ammo -= 1
	_shot_cooldown = 60.0 / config.rounds_per_minute
	_shoot_hitscan()
	_apply_recoil()
	ammo_changed.emit(magazine_ammo, reserve_ammo)

func _shoot_hitscan() -> void:
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var scene := get_tree().current_scene
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server() and scene.has_method("request_network_shot"):
		scene.request_network_shot(origin, direction)
		return
	_shoot_hitscan_from(origin, direction)

func _shoot_hitscan_from(origin: Vector3, direction: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * config.max_range)
	query.collision_mask = 5
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.get("collider")
	if collider != null and collider.has_method("apply_damage"):
		collider.apply_damage(config.damage, result.position)
		hit_confirmed.emit()

func _apply_recoil() -> void:
	var yaw := _rng.randf_range(-config.recoil_yaw, config.recoil_yaw)
	_recoil_offset = Vector3(0.0, 0.0, 0.08)
	if player.has_method("add_camera_recoil"):
		player.add_camera_recoil(config.recoil_pitch, yaw)

func _start_reload() -> void:
	if is_reloading or magazine_ammo >= config.magazine_size or reserve_ammo <= 0:
		return
	_reload_remaining = config.reload_time
	reload_started.emit(config.reload_time)

func _finish_reload() -> void:
	var needed := config.magazine_size - magazine_ammo
	var loaded := mini(needed, reserve_ammo)
	magazine_ammo += loaded
	reserve_ammo -= loaded
	_reload_remaining = 0.0
	ammo_changed.emit(magazine_ammo, reserve_ammo)
	reload_finished.emit()
