class_name WaveController
extends Node3D
## Owns wave progression and spawning; enemy behaviour remains in MeleeEnemy.

signal wave_started(number: int, total: int)
signal enemy_count_changed(alive: int, pending: int)
signal intermission_changed(remaining: float)
signal wave_finished(number: int)
signal run_stats_changed(wave: int, kills: int, survival_time: float)
signal enemy_spawned(enemy_id: int, position: Vector3)
signal enemy_removed(enemy_id: int)
signal enemy_health_changed(enemy_id: int, current: float, maximum: float)

@export_category("Wave")
@export var first_wave_count: int = 3
@export var enemies_added_per_wave: int = 1
@export var time_between_waves: float = 5.0
@export var spawn_interval: float = 0.45
@export var max_spawn_attempts: int = 12
@export_category("Spawn")
@export var min_spawn_distance_from_player: float = 7.0
@export var spawn_clearance_radius: float = 0.8
@export var enemy_scene: PackedScene = preload("res://scenes/enemies/melee_enemy.tscn")
@export var spawn_points_root_path: NodePath = NodePath("../EnemySpawnPoints")
@export var enemy_parent_path: NodePath = NodePath("..")
@export var player_path: NodePath = NodePath("../Player")

var current_wave: int = 0
var alive_enemy_count: int = 0
var pending_enemy_count: int = 0
var intermission_remaining: float = 0.0
var is_running: bool = false
var total_kills: int = 0
var survival_time: float = 0.0

var _spawn_timer := 0.0
var _spawn_failures := 0
var _active_enemies: Dictionary = {}
var _state := State.IDLE
var _player: Node3D
var _enemy_parent: Node
var _spawn_points_root: Node3D
var _clearance_shape: SphereShape3D
var _next_enemy_id := 1

enum State { IDLE, SPAWNING, ACTIVE, WAITING, STOPPED }

func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_enemy_parent = get_node_or_null(enemy_parent_path)
	_spawn_points_root = get_node_or_null(spawn_points_root_path) as Node3D
	_clearance_shape = SphereShape3D.new()
	_clearance_shape.radius = spawn_clearance_radius

func start() -> void:
	if is_running or _state == State.STOPPED:
		return
	current_wave = 0
	total_kills = 0
	survival_time = 0.0
	is_running = true
	_begin_next_wave()

func stop() -> void:
	is_running = false
	_state = State.STOPPED
	for enemy in _active_enemies.keys():
		if is_instance_valid(enemy) and enemy.has_method("set_physics_process"):
			enemy.set_physics_process(false)
	pending_enemy_count = 0
	intermission_remaining = 0.0
	intermission_changed.emit(0.0)
	_emit_enemy_count()

func spawn_test_enemy() -> bool:
	if not is_running or _state == State.STOPPED:
		return false
	var spawn_position: Variant = _find_spawn_position()
	if spawn_position == null:
		return false
	var enemy: Node = _create_enemy(Vector3(spawn_position))
	return enemy != null

func spawn_network_replica(enemy_id: int, position: Vector3) -> Node:
	if enemy_scene == null or _enemy_parent == null:
		return null
	var enemy := enemy_scene.instantiate()
	enemy.set_meta("network_replica", true)
	enemy.set_meta("network_id", enemy_id)
	_enemy_parent.add_child(enemy)
	enemy.global_position = position
	return enemy

func get_network_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for enemy in _active_enemies.keys():
		if is_instance_valid(enemy):
			var health := enemy.get_node_or_null("Health") as HealthComponent
			snapshots.append({"id": int(enemy.get_meta("network_id", -1)), "position": enemy.global_position, "health": health.current_health if health != null else 0.0})
	return snapshots

func _process(delta: float) -> void:
	if not is_running:
		return
	survival_time += delta
	run_stats_changed.emit(current_wave, total_kills, survival_time)
	match _state:
		State.SPAWNING:
			_process_spawning(delta)
		State.ACTIVE:
			_try_finish_wave()
		State.WAITING:
			_process_intermission(delta)

func _begin_next_wave() -> void:
	current_wave += 1
	pending_enemy_count = first_wave_count + (current_wave - 1) * enemies_added_per_wave
	_spawn_timer = 0.0
	_spawn_failures = 0
	_state = State.SPAWNING
	wave_started.emit(current_wave, pending_enemy_count)
	_emit_enemy_count()

func _process_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if pending_enemy_count > 0 and _spawn_timer <= 0.0:
		if _spawn_one_enemy():
			_spawn_timer = spawn_interval
		else:
			_spawn_failures += 1
			_spawn_timer = 0.25
			if _spawn_failures >= max_spawn_attempts:
				# Avoid a deadlock if every point is blocked; the next wave can retry later.
				pending_enemy_count -= 1
				_spawn_failures = 0
				_emit_enemy_count()
	if pending_enemy_count <= 0:
		_state = State.ACTIVE
		_try_finish_wave()

func _process_intermission(delta: float) -> void:
	intermission_remaining = maxf(intermission_remaining - delta, 0.0)
	intermission_changed.emit(intermission_remaining)
	if intermission_remaining <= 0.0:
		_begin_next_wave()

func _spawn_one_enemy() -> bool:
	var spawn_position: Variant = _find_spawn_position()
	if spawn_position == null:
		return false
	var enemy: Node = _create_enemy(Vector3(spawn_position))
	if enemy == null:
		return false
	pending_enemy_count -= 1
	_emit_enemy_count()
	return true

func _create_enemy(spawn_position: Vector3) -> Node:
	if enemy_scene == null or _enemy_parent == null:
		return null
	var enemy := enemy_scene.instantiate()
	var enemy_id := _next_enemy_id
	_next_enemy_id += 1
	enemy.set_meta("network_id", enemy_id)
	_enemy_parent.add_child(enemy)
	enemy.global_position = spawn_position
	_track_enemy(enemy)
	enemy_spawned.emit(enemy_id, spawn_position)
	return enemy

func _track_enemy(enemy: Node) -> void:
	_active_enemies[enemy] = true
	var health := enemy.get_node_or_null("Health") as HealthComponent
	if health != null:
		health.died.connect(_on_enemy_died.bind(enemy))
		health.health_changed.connect(_on_enemy_health_changed.bind(enemy))
	enemy.tree_exited.connect(_on_enemy_exited.bind(enemy))
	_emit_enemy_count()

func _on_enemy_died(enemy: Node) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	enemy_removed.emit(int(enemy.get_meta("network_id", -1)))
	total_kills += 1
	run_stats_changed.emit(current_wave, total_kills, survival_time)
	_emit_enemy_count()
	_try_finish_wave()

func _on_enemy_health_changed(current: float, maximum: float, enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy_health_changed.emit(int(enemy.get_meta("network_id", -1)), current, maximum)

func _on_enemy_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	_emit_enemy_count()
	_try_finish_wave()

func _try_finish_wave() -> void:
	if _state != State.ACTIVE or pending_enemy_count > 0 or not _active_enemies.is_empty():
		return
	_state = State.WAITING
	intermission_remaining = time_between_waves
	wave_finished.emit(current_wave)
	intermission_changed.emit(intermission_remaining)

func _emit_enemy_count() -> void:
	alive_enemy_count = _active_enemies.size()
	enemy_count_changed.emit(alive_enemy_count, pending_enemy_count)

func _find_spawn_position() -> Variant:
	if _spawn_points_root == null:
		return null
	var candidates: Array[Vector3] = []
	for child in _spawn_points_root.get_children():
		if child is Node3D:
			candidates.append((child as Node3D).global_position)
	candidates.shuffle()
	for position in candidates:
		if _is_spawn_position_valid(position):
			return position
	return null

func _is_spawn_position_valid(position: Vector3) -> bool:
	if _player != null and _player.global_position.distance_to(position) < min_spawn_distance_from_player:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.9)
	query.collision_mask = 5
	query.collide_with_bodies = true
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()
