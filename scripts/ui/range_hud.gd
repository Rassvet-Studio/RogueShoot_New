class_name RangeHUD
extends CanvasLayer

@onready var ammo_label: Label = $Margin/VBox/Ammo
@onready var status_label: Label = $Margin/VBox/Status
@onready var hit_marker: Label = $HitMarker
@onready var module_label: Label = $Margin/VBox/Module
var _hit_marker_time := 0.0

func _ready() -> void:
	hit_marker.visible = false

func bind_weapon(weapon: AutomaticRifle) -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.hit_confirmed.connect(_on_hit)
	_on_ammo_changed(weapon.magazine_ammo, weapon.reserve_ammo)
	module_label.text = "Модуль отдачи: " + ("ВКЛ" if weapon.config.recoil_module_enabled else "ВЫКЛ")

func _process(delta: float) -> void:
	if _hit_marker_time > 0.0:
		_hit_marker_time -= delta
		if _hit_marker_time <= 0.0:
			hit_marker.visible = false

func _on_ammo_changed(magazine: int, reserve: int) -> void:
	ammo_label.text = "%02d / %03d" % [magazine, reserve]

func _on_reload_started(_duration: float) -> void:
	status_label.text = "ПЕРЕЗАРЯДКА..."

func _on_reload_finished() -> void:
	status_label.text = ""

func _on_hit() -> void:
	hit_marker.visible = true
	_hit_marker_time = 0.12
