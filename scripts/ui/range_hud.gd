class_name RangeHUD
extends CanvasLayer

@onready var ammo_label: Label = $Margin/VBox/Ammo
@onready var status_label: Label = $Margin/VBox/Status
@onready var hit_marker: Label = $HitMarker
@onready var module_label: Label = $Margin/VBox/Module
@onready var slide_label: Label = $Margin/VBox/Slide
@onready var health_bar: ProgressBar = $Margin/VBox/Health
@onready var defeat_panel: PanelContainer = $DefeatPanel
var _hit_marker_time := 0.0
var _player: FPSPlayer

func _ready() -> void:
	hit_marker.visible = false
	defeat_panel.hide()

func bind_weapon(weapon: AutomaticRifle) -> void:
	weapon.ammo_changed.connect(_on_ammo_changed)
	weapon.reload_started.connect(_on_reload_started)
	weapon.reload_finished.connect(_on_reload_finished)
	weapon.hit_confirmed.connect(_on_hit)
	_on_ammo_changed(weapon.magazine_ammo, weapon.reserve_ammo)
	module_label.text = "Модуль отдачи: " + ("ВКЛ" if weapon.config.recoil_module_enabled else "ВЫКЛ")

func bind_player(player: FPSPlayer) -> void:
	_player = player
	_player.health.health_changed.connect(_on_player_health_changed)
	_player.health.died.connect(show_defeat)
	_on_player_health_changed(_player.health.current_health, _player.health.max_health)

func is_defeat_visible() -> bool:
	return defeat_panel.visible

func show_defeat() -> void:
	defeat_panel.show()
	status_label.text = ""

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _update_slide_indicator() -> void:
	if _player == null:
		return
	if _player.is_sliding:
		slide_label.text = "СКОЛЬЖЕНИЕ"
		slide_label.modulate = Color(1.0, 0.8, 0.3, 1.0)
	elif _player.slide_cooldown_remaining > 0.0:
		slide_label.text = "СКОЛЬЖЕНИЕ: КД %.1f" % _player.slide_cooldown_remaining
		slide_label.modulate = Color(0.65, 0.65, 0.7, 1.0)
	else:
		slide_label.text = "СКОЛЬЖЕНИЕ: ГОТОВО"
		slide_label.modulate = Color(0.55, 1.0, 0.65, 1.0)

func _process(delta: float) -> void:
	_update_slide_indicator()
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
