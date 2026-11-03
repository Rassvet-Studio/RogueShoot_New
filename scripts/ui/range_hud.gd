class_name RangeHUD
extends CanvasLayer

@onready var ammo_label: Label = $Margin/VBox/Ammo
@onready var status_label: Label = $Margin/VBox/Status
@onready var hit_marker: Label = $HitMarker
@onready var module_label: Label = $Margin/VBox/Module
@onready var slide_label: Label = $Margin/VBox/Slide
@onready var health_bar: ProgressBar = $Margin/VBox/Health
@onready var defeat_panel: PanelContainer = $DefeatPanel
@onready var wave_label: Label = $WaveInfo/Wave
@onready var enemies_label: Label = $WaveInfo/Enemies
@onready var next_wave_label: Label = $WaveInfo/NextWave
@onready var wave_announcement: Label = $WaveAnnouncement
@onready var result_wave_label: Label = $DefeatPanel/Center/VBox/WaveResult
@onready var result_kills_label: Label = $DefeatPanel/Center/VBox/KillsResult
@onready var result_time_label: Label = $DefeatPanel/Center/VBox/TimeResult
var _hit_marker_time := 0.0
var _wave_announcement_time := 0.0
var _player: FPSPlayer

func _ready() -> void:
	hit_marker.visible = false
	defeat_panel.hide()
	wave_announcement.visible = false

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
	_on_player_health_changed(_player.health.current_health, _player.health.max_health)

func bind_wave_controller(controller: WaveController) -> void:
	controller.wave_started.connect(_on_wave_started)
	controller.enemy_count_changed.connect(_on_enemy_count_changed)
	controller.intermission_changed.connect(_on_intermission_changed)
	_on_enemy_count_changed(controller.alive_enemy_count, controller.pending_enemy_count)

func _on_wave_started(number: int, total: int) -> void:
	wave_label.text = "Волна %d" % number
	wave_announcement.text = "ВОЛНА %d" % number
	wave_announcement.visible = true
	_wave_announcement_time = 1.6
	_on_enemy_count_changed(0, total)

func _on_enemy_count_changed(alive: int, pending: int) -> void:
	enemies_label.text = "Противники: %d" % (alive + pending)

func _on_intermission_changed(remaining: float) -> void:
	if remaining > 0.0:
		next_wave_label.text = "Следующая волна: %.1f" % remaining
	else:
		next_wave_label.text = "Следующая волна: —"

func is_defeat_visible() -> bool:
	return defeat_panel.visible


func show_results(wave: int, kills: int, survival_time: float) -> void:
	if defeat_panel.visible:
		return
	result_wave_label.text = "Достигнутая волна: %d" % wave
	result_kills_label.text = "Убито врагов: %d" % kills
	var total_seconds := maxi(int(survival_time), 0)
	result_time_label.text = "Время выживания: %02d:%02d" % [total_seconds / 60, total_seconds % 60]
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
	if _wave_announcement_time > 0.0:
		_wave_announcement_time -= delta
		if _wave_announcement_time <= 0.0:
			wave_announcement.visible = false
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
