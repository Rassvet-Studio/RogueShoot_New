class_name HealthComponent
extends Node
## Reusable health and damage contract for players, enemies and future network actors.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var current_health: float
var is_dead: bool = false

func _ready() -> void:
	reset_health()

func reset_health() -> void:
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)

func apply_damage(amount: float, _source: Node = null) -> bool:
	if is_dead or amount <= 0.0:
		return false
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()
	return true

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
