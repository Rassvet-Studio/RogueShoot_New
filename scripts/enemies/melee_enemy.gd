class_name MeleeEnemy
extends CharacterBody3D
## Small navigation-driven melee enemy. Target selection is group-based for future co-op.

@export_category("Detection")
@export var detection_radius: float = 18.0
@export var attack_range: float = 1.7
@export_category("Movement")
@export var move_speed: float = 3.2
@export var acceleration: float = 12.0
@export var stopping_acceleration: float = 18.0
@export_category("Attack")
@export var attack_damage: float = 15.0
@export var attack_interval: float = 1.1
@export var attack_windup: float = 0.18

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health: HealthComponent = $Health
@onready var visual: MeshInstance3D = $Visual

var _target: Node3D
var _attack_cooldown := 0.0
var _attack_windup_remaining := 0.0
var _hit_flash_remaining := 0.0
var _base_material: Material
var _hit_material: StandardMaterial3D
var _attack_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("enemies")
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	if has_meta("network_replica"):
		set_physics_process(false)
		navigation_agent.avoidance_enabled = false
	_base_material = visual.material_override
	_hit_material = _make_flash_material(Color(1.0, 0.15, 0.08, 1.0))
	_attack_material = _make_flash_material(Color(1.0, 0.65, 0.08, 1.0))
	navigation_agent.path_desired_distance = 0.35
	navigation_agent.target_desired_distance = attack_range * 0.8
	navigation_agent.radius = 0.45
	navigation_agent.height = 1.8
	navigation_agent.avoidance_enabled = true
	navigation_agent.max_speed = move_speed

func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_windup_remaining > 0.0:
		_attack_windup_remaining -= delta
		if _attack_windup_remaining <= 0.0:
			_perform_attack()
	_update_flash(delta)
	_target = _find_target()
	if _target == null:
		_stop(delta)
		move_and_slide()
		return
	var offset := _target.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	if distance <= attack_range:
		_stop(delta)
		_face_target(_target, delta)
		_try_attack()
	else:
		_chase_target(delta)
	move_and_slide()

func _find_target() -> Node3D:
	var nearest: Node3D
	var nearest_distance := detection_radius
	for candidate in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate.has_method("is_alive") and not candidate.is_alive():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _chase_target(delta: float) -> void:
	if not navigation_agent.is_navigation_finished():
		navigation_agent.target_position = _target.global_position
	else:
		navigation_agent.target_position = _target.global_position
	var next_position := navigation_agent.get_next_path_position()
	var current_path := navigation_agent.get_current_navigation_path()
	if current_path.size() > 1:
		next_position = current_path[1]
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		_stop(delta)
		return
	direction = direction.normalized()
	var desired := direction * move_speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	_face_direction(direction, delta)

func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stopping_acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, stopping_acceleration * delta)

func _face_target(target: Node3D, delta: float) -> void:
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		_face_direction(direction.normalized(), delta)

func _face_direction(direction: Vector3, delta: float) -> void:
	var target_angle := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, minf(delta * 10.0, 1.0))

func _try_attack() -> void:
	if _attack_cooldown > 0.0 or _attack_windup_remaining > 0.0:
		return
	_attack_cooldown = attack_interval
	_attack_windup_remaining = attack_windup
	visual.material_override = _attack_material

func _perform_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > attack_range + 0.35:
		return
	if _target.has_method("apply_damage"):
		_target.apply_damage(attack_damage, self)

func apply_damage(amount: float, source = null) -> bool:
	return health.apply_damage(amount, source)

func _on_health_changed(current: float, _maximum: float) -> void:
	if current < health.max_health and not health.is_dead:
		_hit_flash_remaining = 0.12
		visual.material_override = _hit_material

func _on_died() -> void:
	set_physics_process(false)
	navigation_agent.avoidance_enabled = false
	$CollisionShape3D.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)

func _update_flash(delta: float) -> void:
	if _hit_flash_remaining > 0.0:
		_hit_flash_remaining -= delta
		if _hit_flash_remaining <= 0.0 and _attack_windup_remaining <= 0.0:
			visual.material_override = _base_material

func _make_flash_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.45
	return material
