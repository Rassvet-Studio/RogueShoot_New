class_name DamageableTarget
extends StaticBody3D
## Small target contract for future enemies and network-owned actors.

signal health_changed(current: float, maximum: float)
signal defeated

@export var max_health: float = 100.0
@export var hit_flash_duration: float = 0.12
@onready var visual: MeshInstance3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var health: float
var _base_material: Material
var _hit_material: StandardMaterial3D
var _flash_time := 0.0

func _ready() -> void:
	health = max_health
	_base_material = visual.material_override
	_hit_material = StandardMaterial3D.new()
	_hit_material.albedo_color = Color(1.0, 0.18, 0.1, 1.0)
	_hit_material.emission_enabled = true
	_hit_material.emission = Color(0.8, 0.05, 0.02, 1.0)

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			visual.material_override = _base_material

func apply_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if health <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_flash_time = hit_flash_duration
	visual.material_override = _hit_material
	health_changed.emit(health, max_health)
	if health <= 0.0:
		defeated.emit()
		# Keep the target in the range as a reusable resettable test object.
		await get_tree().create_timer(0.35).timeout
		health = max_health
		visual.material_override = _base_material
		health_changed.emit(health, max_health)
