extends Node2D
class_name LevelBase

## The base root of every farm level.
## It configures its own Map Bounds and registers with the GameManager.

@export var map_extents := Vector2(170, 105)
@export var level_data: LevelData

@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var timer_label: Label = $UI/TimerLabel
@onready var gold_label: GoldCounterLabel = $UI/GoldLabel

const ENEMY_SPAWNER_SCRIPT := preload("res://Scripts/Level/enemy_spawner.gd")
const DAY_NIGHT_CONTROLLER_SCRIPT := preload("res://Scripts/Level/day_night_controller.gd")

var _remaining_time_seconds := 300.0


func _ready() -> void:
	var level_time_limit := 300.0
	var level_starting_gold := CurrencyManager.gold
	if level_data:
		level_time_limit = level_data.time_limit_seconds
		level_starting_gold = maxi(0, level_data.starting_gold)

	# Register the current boundaries so Goblin AI and game systems know
	GameManager.register_level(map_extents, scene_file_path, {
		"time_limit_seconds": level_time_limit,
		"starting_gold": level_starting_gold,
	})
	
	# Instantiate EnemySpawner if map is configured with Waves
	if level_data:
		var spawner = ENEMY_SPAWNER_SCRIPT.new()
		spawner.level_data = level_data
		add_child(spawner)

	if level_data and level_data.has_day_night_cycle:
		_setup_day_night_cycle()
	else:
		day_night_modulate.color = Color.WHITE

	if GameManager.has_signal("level_timer_changed") and not GameManager.level_timer_changed.is_connected(_on_level_timer_changed):
		GameManager.level_timer_changed.connect(_on_level_timer_changed)
	_on_level_timer_changed(level_time_limit, level_time_limit)

	if CurrencyManager.has_signal("gold_changed") and not CurrencyManager.gold_changed.is_connected(_on_gold_changed):
		CurrencyManager.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(CurrencyManager.gold)


func _setup_day_night_cycle() -> void:
	var controller = DAY_NIGHT_CONTROLLER_SCRIPT.new()
	controller.name = "DayNightController"
	controller.day_duration_seconds = maxf(1.0, level_data.day_duration_seconds)
	controller.night_duration_seconds = maxf(1.0, level_data.night_duration_seconds)
	controller.transition_duration_seconds = maxf(0.1, level_data.transition_duration_seconds)
	controller.night_enemy_spawn_interval_multiplier = maxf(0.05, level_data.night_enemy_spawn_interval_multiplier)
	controller.night_crop_growth_rate_multiplier = maxf(0.05, level_data.night_crop_growth_rate_multiplier)
	add_child(controller)


func _process(delta: float) -> void:
	if not timer_label:
		return

	if _remaining_time_seconds < 30.0 and not GameManager._game_over:
		var blink_on := (Time.get_ticks_msec() / 250) % 2 == 0
		timer_label.modulate = Color(1.0, 0.2, 0.2, 1.0) if blink_on else Color(1.0, 0.8, 0.8, 1.0)
	else:
		timer_label.modulate = Color.WHITE


func _on_level_timer_changed(remaining_seconds: float, _total_seconds: float) -> void:
	_remaining_time_seconds = remaining_seconds
	if timer_label:
		timer_label.text = _format_mmss(remaining_seconds)


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.set_gold_value(amount)


func _format_mmss(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	var minutes := total / 60
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]
