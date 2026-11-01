class_name DamageableTarget
extends StaticBody3D
## Target wrapper that delegates damage to the reusable health component.

@export var hit_flash_duration: float = 0.12
@onready var visual: MeshInstance3D = $Visual
@onready var health: HealthComponent = $Health

var _base_material: Material
var _hit_material: StandardMaterial3D
var _flash_time := 0.0

func _ready() -> void:
	_base_material = visual.material_override
	_hit_material = StandardMaterial3D.new()
	_hit_material.albedo_color = Color(1.0, 0.18, 0.1, 1.0)
	_hit_material.emission_enabled = true
	_hit_material.emission = Color(0.8, 0.05, 0.02, 1.0)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)

func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			visual.material_override = _base_material

func apply_damage(amount: float, source: Node = null) -> bool:
	return health.apply_damage(amount, source)

func _on_health_changed(current: float, _maximum: float) -> void:
	if current < health.max_health and not health.is_dead:
		_flash_time = hit_flash_duration
		visual.material_override = _hit_material

func _on_died() -> void:
	# Targets reset instead of leaving the range, so the firing test remains repeatable.
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(self):
		health.reset_health()
		visual.material_override = _base_material
