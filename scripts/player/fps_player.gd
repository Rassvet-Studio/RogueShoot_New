class_name FPSPlayer
extends CharacterBody3D
## Extensible local player foundation. Networking can later own player_id/input authority.

@export_category("Movement")
@export var move_speed: float = 6.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 18.0

@export_category("Look")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(-89.0, 0.0, 1.0) var min_pitch: float = -89.0
@export_range(0.0, 89.0, 1.0) var max_pitch: float = 89.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var _pitch_degrees := 0.0

func _ready() -> void:
	add_to_group("players")
	_capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse_capture"):
		_toggle_mouse_capture()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	velocity.x = wish_direction.x * move_speed
	velocity.z = wish_direction.z * move_speed
	move_and_slide()

func _rotate_view(relative_motion: Vector2) -> void:
	rotate_y(deg_to_rad(-relative_motion.x * mouse_sensitivity))
	_pitch_degrees = clamp(_pitch_degrees - relative_motion.y * mouse_sensitivity, min_pitch, max_pitch)
	camera_pivot.rotation_degrees.x = _pitch_degrees

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_release_mouse()
	else:
		_capture_mouse()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
