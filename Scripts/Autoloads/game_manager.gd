extends CanvasLayer

## Autoload that manages cross-level data, win/lose conditions, and the Game Loop UI.

signal level_timer_changed(remaining_seconds: float, total_seconds: float)
signal day_night_changed(is_night: bool)
signal progress_changed(max_unlocked_level: int, last_level_index: int)

const SAVE_PATH := "user://progress.cfg"
const SAVE_SECTION := "progress"
const SAVE_KEY_MAX_UNLOCKED := "max_unlocked_level"
const SAVE_KEY_LAST_LEVEL := "last_level_index"
const LEVEL_SELECTOR_SCENE := "res://Scenes/UI/level_selector.tscn"
const LEVEL_SCENES := [
	"res://Scenes/Level/level_1.tscn",
	"res://Scenes/Level/level_2.tscn",
	"res://Scenes/Level/level_3.tscn",
	"res://Scenes/Level/level_4.tscn",
]

@onready var color_rect: ColorRect = $ColorRect
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var retry_button: Button = $VBoxContainer/HBoxContainer/RetryButton
@onready var next_button: Button = $VBoxContainer/HBoxContainer/NextButton
@onready var vbox: VBoxContainer = $VBoxContainer

var map_extents := Vector2(320, 180) # Default size
var current_level_path := ""
var current_level_index := 1
var max_unlocked_level := 1
var last_level_index := 1

var level_goals := {
	1: {"name": "Unlock Chicken", "price": 500, "icon": null},
	2: {"name": "Unlock Farmer/Warrior", "price": 1000, "icon": null},
	3: {"name": "Unlock Farmland", "price": 1500, "icon": null},
	4: {"name": "Unlock Night", "price": 2500, "icon": null},
	5: {"name": "Ultimate Crown", "price": 4000, "icon": null}
}

func get_current_goal_data() -> Dictionary:
	return level_goals.get(current_level_index, level_goals[1])

var _game_over := false
var _level_elapsed_seconds := 0.0
var _level_time_limit_seconds := 300.0
var _time_limit_checked := false

var _enemy_spawn_interval_multiplier := 1.0
var _crop_growth_rate_multiplier := 1.0
var _is_night := false


func _ready() -> void:
	_load_progress()
	hide_ui()
	retry_button.pressed.connect(_on_retry_pressed)
	next_button.pressed.connect(_on_next_pressed)


func register_level(extents: Vector2, scene_path: String, config: Dictionary = {}) -> void:
	map_extents = extents
	current_level_path = scene_path
	current_level_index = _find_level_index_by_scene(scene_path)
	last_level_index = current_level_index
	_save_progress()
	_game_over = false
	_level_elapsed_seconds = 0.0
	_level_time_limit_seconds = maxf(1.0, float(config.get("time_limit_seconds", 300.0)))
	var level_starting_gold := maxi(0, int(config.get("starting_gold", CurrencyManager.gold)))
	CurrencyManager.set_gold(level_starting_gold)
	_time_limit_checked = false
	set_day_night_modifiers(false, 1.0, 1.0)
	level_timer_changed.emit(_level_time_limit_seconds, _level_time_limit_seconds)
	hide_ui()
	UpgradeManager.reset_upgrades()


func _process(delta: float) -> void:
	if _game_over:
		return

	_level_elapsed_seconds += delta
	var remaining := get_remaining_time_seconds()
	level_timer_changed.emit(remaining, _level_time_limit_seconds)

	if _time_limit_checked:
		return
	if remaining > 0.0:
		return

	_time_limit_checked = true
	lose()


func get_remaining_time_seconds() -> float:
	return maxf(0.0, _level_time_limit_seconds - _level_elapsed_seconds)


func get_enemy_spawn_interval_multiplier() -> float:
	return _enemy_spawn_interval_multiplier


func get_crop_growth_rate_multiplier() -> float:
	return _crop_growth_rate_multiplier


func is_night_time() -> bool:
	return _is_night


func set_day_night_modifiers(is_night: bool, enemy_spawn_interval_multiplier: float = 1.0, crop_growth_rate_multiplier: float = 1.0) -> void:
	_is_night = is_night
	_enemy_spawn_interval_multiplier = maxf(0.05, enemy_spawn_interval_multiplier)
	_crop_growth_rate_multiplier = maxf(0.05, crop_growth_rate_multiplier)
	day_night_changed.emit(_is_night)


func win() -> void:
	if _game_over:
		return
	_game_over = true
	get_tree().paused = true
	title_label.text = "LEVEL COMPLETE!"
	title_label.modulate = Color.WHITE
	color_rect.color = Color(0, 0, 0, 0.7)
	next_button.text = " Level Select " if current_level_index >= LEVEL_SCENES.size() else " Next Level "
	next_button.show()
	show_ui()


func lose() -> void:
	if _game_over:
		return
	_game_over = true
	get_tree().paused = true
	title_label.text = "TRY AGAIN"
	title_label.modulate = Color.INDIAN_RED
	color_rect.color = Color(0, 0, 0, 0.8)
	next_button.hide()
	show_ui()


func show_ui() -> void:
	visible = true


func hide_ui() -> void:
	visible = false
	get_tree().paused = false


func _on_retry_pressed() -> void:
	get_tree().paused = false
	if current_level_path != "":
		get_tree().change_scene_to_file(current_level_path)
	else:
		get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	get_tree().paused = false
	if current_level_index < LEVEL_SCENES.size():
		go_to_level(current_level_index + 1)
	else:
		go_to_level_selector()


func complete_current_level() -> void:
	var next_level := current_level_index + 1
	if next_level > max_unlocked_level:
		max_unlocked_level = min(next_level, LEVEL_SCENES.size())
		_save_progress()

	if current_level_index < LEVEL_SCENES.size():
		go_to_level(current_level_index + 1)
		return

	win()


func go_to_level(level_index: int) -> void:
	if level_index < 1 or level_index > LEVEL_SCENES.size():
		return
	if not is_level_unlocked(level_index):
		return

	current_level_index = level_index
	last_level_index = level_index
	_save_progress()
	hide_ui()
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENES[level_index - 1])


func go_to_level_selector() -> void:
	hide_ui()
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SELECTOR_SCENE)


func is_level_unlocked(level_index: int) -> bool:
	return level_index >= 1 and level_index <= max_unlocked_level


func get_max_unlocked_level() -> int:
	return max_unlocked_level


func get_last_level_index() -> int:
	return last_level_index


func _find_level_index_by_scene(scene_path: String) -> int:
	for i in range(LEVEL_SCENES.size()):
		if LEVEL_SCENES[i] == scene_path:
			return i + 1
	return current_level_index


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		max_unlocked_level = 1
		last_level_index = 1
		current_level_index = 1
		progress_changed.emit(max_unlocked_level, last_level_index)
		return

	max_unlocked_level = clampi(int(cfg.get_value(SAVE_SECTION, SAVE_KEY_MAX_UNLOCKED, 1)), 1, LEVEL_SCENES.size())
	last_level_index = clampi(int(cfg.get_value(SAVE_SECTION, SAVE_KEY_LAST_LEVEL, 1)), 1, max_unlocked_level)
	current_level_index = last_level_index
	progress_changed.emit(max_unlocked_level, last_level_index)


func _save_progress() -> void:
	max_unlocked_level = clampi(max_unlocked_level, 1, LEVEL_SCENES.size())
	last_level_index = clampi(last_level_index, 1, max_unlocked_level)

	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, SAVE_KEY_MAX_UNLOCKED, max_unlocked_level)
	cfg.set_value(SAVE_SECTION, SAVE_KEY_LAST_LEVEL, last_level_index)
	var _err := cfg.save(SAVE_PATH)
	progress_changed.emit(max_unlocked_level, last_level_index)
