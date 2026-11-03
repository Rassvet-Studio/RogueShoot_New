class_name FPSPlayer
extends CharacterBody3D
## Extensible local player foundation. Networking can later own player_id/input authority.

signal slide_state_changed(active: bool)
signal defeated

@export_category("Movement")
@export var move_speed: float = 6.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 18.0

@export_category("Slide")
@export var slide_impulse_speed: float = 6.0
@export var slide_friction: float = 10.0
@export var slide_min_speed: float = 3.5
@export var slide_max_duration: float = 0.9
@export var slide_cooldown: float = 3.0
@export var slide_steer_strength: float = 7.0
@export var slide_camera_height: float = 0.95
@export var slide_camera_speed: float = 8.0
@export var standing_camera_height: float = 1.6

@export_category("Look")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(-89.0, 0.0, 1.0) var min_pitch: float = -89.0
@export_range(0.0, 89.0, 1.0) var max_pitch: float = 89.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var health: HealthComponent = $Health

var _pitch_degrees := 0.0
var _recoil_pitch := 0.0
var _is_sliding := false
var _slide_elapsed := 0.0
var _slide_cooldown_remaining := 0.0
var _network_controlled := false
var _network_peer_id := 1
var _network_target_position := Vector3.ZERO
var _network_target_yaw := 0.0
var _network_target_pitch := 0.0

var is_sliding: bool:
	get:
		return _is_sliding

var slide_cooldown_remaining: float:
	get:
		return _slide_cooldown_remaining

var slide_ready: bool:
	get:
		return not _is_sliding and _slide_cooldown_remaining <= 0.0

func _ready() -> void:
	add_to_group("players")
	health.died.connect(_on_died)
	if not has_meta("network_remote"):
		_capture_mouse()

func start_control() -> void:
	if not _network_controlled or is_multiplayer_authority():
		_capture_mouse()

func configure_network(peer_id: int, locally_controlled: bool) -> void:
	_network_controlled = true
	_network_peer_id = peer_id
	set_multiplayer_authority(peer_id)
	if not locally_controlled:
		camera.current = false
		$CameraPivot/AutomaticRifle.set_physics_process(false)

func apply_network_transform(position: Vector3, yaw: float, pitch: float) -> void:
	if not _network_controlled or is_multiplayer_authority():
		return
	_network_target_position = position
	_network_target_yaw = yaw
	_network_target_pitch = pitch

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_mouse_capture()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative)

func _physics_process(delta: float) -> void:
	if _network_controlled and not is_multiplayer_authority():
		global_position = global_position.lerp(_network_target_position, minf(delta * 12.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _network_target_yaw, minf(delta * 12.0, 1.0))
		camera_pivot.rotation_degrees.x = rad_to_deg(_network_target_pitch)
		return
	if not is_alive():
		velocity = Vector3.ZERO
		return
	_slide_cooldown_remaining = move_toward(_slide_cooldown_remaining, 0.0, delta)
	var was_on_floor := is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		_end_slide()
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	if _is_sliding:
		_process_slide(delta, wish_direction)
	else:
		velocity.x = wish_direction.x * move_speed
		velocity.z = wish_direction.z * move_speed
		if was_on_floor and Input.is_action_just_pressed("slide"):
			_begin_slide(wish_direction)
	move_and_slide()
	if _is_sliding and not is_on_floor():
		_end_slide()
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, 8.0 * delta)
	camera_pivot.rotation_degrees.x = _pitch_degrees + _recoil_pitch
	var target_camera_height := slide_camera_height if _is_sliding else standing_camera_height
	camera_pivot.position.y = move_toward(camera_pivot.position.y, target_camera_height, slide_camera_speed * delta)
	if _network_controlled:
		var scene := get_tree().current_scene
		if scene.has_method("broadcast_player_transform"):
			scene.broadcast_player_transform(_network_peer_id, global_position, rotation.y, camera_pivot.rotation.x)


func _begin_slide(wish_direction: Vector3) -> void:
	if not slide_ready or wish_direction == Vector3.ZERO or not is_on_floor():
		return
	_is_sliding = true
	_slide_elapsed = 0.0
	_slide_cooldown_remaining = slide_cooldown
	var launch_speed := _horizontal_speed() + slide_impulse_speed
	velocity.x = wish_direction.x * launch_speed
	velocity.z = wish_direction.z * launch_speed
	slide_state_changed.emit(true)

func _end_slide() -> void:
	if not _is_sliding:
		return
	_is_sliding = false
	slide_state_changed.emit(false)

func _process_slide(delta: float, wish_direction: Vector3) -> void:
	_slide_elapsed += delta
	if not is_on_floor() or _slide_elapsed >= slide_max_duration:
		_end_slide()
		return
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	var speed := horizontal_velocity.length()
	if speed <= slide_min_speed:
		_end_slide()
		return
	if wish_direction != Vector3.ZERO:
		var desired_velocity := Vector2(wish_direction.x, wish_direction.z) * speed
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, slide_steer_strength * speed * delta)
	horizontal_velocity = horizontal_velocity.move_toward(Vector2.ZERO, slide_friction * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y

func _horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func apply_damage(amount: float, source = null) -> bool:
	return health.apply_damage(amount, source)

func is_alive() -> bool:
	return not health.is_dead

func _on_died() -> void:
	_end_slide()
	defeated.emit()

func _rotate_view(relative_motion: Vector2) -> void:
	rotate_y(deg_to_rad(-relative_motion.x * mouse_sensitivity))
	_pitch_degrees = clamp(_pitch_degrees - relative_motion.y * mouse_sensitivity, min_pitch, max_pitch)
	camera_pivot.rotation_degrees.x = _pitch_degrees + _recoil_pitch

func add_camera_recoil(pitch: float, yaw: float) -> void:
	_recoil_pitch = clampf(_recoil_pitch + pitch, -20.0, 20.0)
	rotation_degrees.y += yaw

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_release_mouse()
	else:
		_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
