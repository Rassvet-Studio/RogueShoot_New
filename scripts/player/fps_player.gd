class_name FPSPlayer
extends CharacterBody3D
## Extensible local player foundation. Networking can later own player_id/input authority.

@export_category("Movement")
@export var move_speed: float = 6.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 18.0

@export_category("Slide")
@export var slide_friction: float = 4.5
@export var slide_min_speed: float = 4.5
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

var _pitch_degrees := 0.0
var _recoil_pitch := 0.0
var _is_sliding := false

var is_sliding: bool:
	get:
		return _is_sliding

func _ready() -> void:
	add_to_group("players")
	_capture_mouse()

func start_control() -> void:
	_capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_mouse_capture()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative)

func _physics_process(delta: float) -> void:
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
		if was_on_floor and Input.is_action_pressed("slide") and wish_direction != Vector3.ZERO and _horizontal_speed() >= slide_min_speed:
			_begin_slide()
	move_and_slide()
	if _is_sliding and not is_on_floor():
		_end_slide()
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, 8.0 * delta)
	camera_pivot.rotation_degrees.x = _pitch_degrees + _recoil_pitch
	var target_camera_height := slide_camera_height if _is_sliding else standing_camera_height
	camera_pivot.position.y = move_toward(camera_pivot.position.y, target_camera_height, slide_camera_speed * delta)

func _begin_slide() -> void:
	_is_sliding = true

func _end_slide() -> void:
	_is_sliding = false

func _process_slide(delta: float, wish_direction: Vector3) -> void:
	if not Input.is_action_pressed("slide") or not is_on_floor():
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
