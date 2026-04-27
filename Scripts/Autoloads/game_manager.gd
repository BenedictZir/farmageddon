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
	1: {"name": "???", "price": 300, "icon": load("res://Assets/animal_and_fertilizer_icon.png")},
	2: {"name": "???", "price": 600, "icon":  load("res://Assets/shovel_and_sword_icon.png")},
	3: {"name": "???", "price": 1000, "icon":  load("res://Assets/moon.png")},
	4: {"name": "???", "price": 1500, "icon":  load("res://Assets/trophy.png")},
}

func get_current_level_index() -> int:
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.scene_file_path != "":
		var resolved_index := _find_level_index_by_scene(scene_root.scene_file_path)
		if resolved_index >= 1 and resolved_index <= LEVEL_SCENES.size():
			current_level_index = resolved_index
	return current_level_index


func get_current_goal_data() -> Dictionary:
	return level_goals.get(get_current_level_index(), level_goals[1])

var _game_over := false
var _level_elapsed_seconds := 0.0
var _level_time_limit_seconds := 300.0
var _time_limit_checked := false
var _level_timer_paused := false

var _enemy_spawn_interval_multiplier := 1.0
var _crop_growth_rate_multiplier := 1.0
var _is_night := false

# ── Tutorial Input Locking ───────────────────────────────────────────
var tutorial_active := false
var _tutorial_unlocked_inputs: Dictionary = {}  # { "move_up": true, "interact": true, ... }


## Check if an input action is allowed (returns true if no tutorial or if unlocked)
func is_input_unlocked(action: String) -> bool:
	if not tutorial_active:
		return true
	return _tutorial_unlocked_inputs.get(action, false)


## Unlock specific input actions during tutorial
func unlock_input(action: String) -> void:
	# Expand shorthand groups
	if action == "move":
		_tutorial_unlocked_inputs["move"] = true
		for a in ["move_up", "move_down", "move_left", "move_right"]:
			_tutorial_unlocked_inputs[a] = true
		return
	_tutorial_unlocked_inputs[action] = true


## Unlock multiple inputs at once
func unlock_inputs(actions: Array) -> void:
	for a in actions:
		unlock_input(a)


## Unlock all inputs (called when tutorial ends)
func unlock_all_inputs() -> void:
	tutorial_active = false
	_tutorial_unlocked_inputs.clear()


func _ready() -> void:
	_load_progress()
	hide_ui()
	retry_button.pressed.connect(_on_retry_pressed)
	next_button.pressed.connect(_on_next_pressed)


func register_level(extents: Vector2, scene_path: String, config: Dictionary = {}) -> void:
	map_extents = extents
	var resolved_scene_path := scene_path
	var scene_root := get_tree().current_scene
	if scene_root and scene_root.scene_file_path != "":
		resolved_scene_path = scene_root.scene_file_path

	current_level_path = resolved_scene_path
	current_level_index = _find_level_index_by_scene(resolved_scene_path)
	last_level_index = current_level_index
	_save_progress()
	_game_over = false
	_level_elapsed_seconds = 0.0
	_level_time_limit_seconds = maxf(1.0, float(config.get("time_limit_seconds", 300.0)))
	_level_timer_paused = false
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
	# Don't tick the timer while the tree is paused (pause screen)
	if get_tree().paused or _level_timer_paused:
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


func pause_level_timer() -> void:
	_level_timer_paused = true


func resume_level_timer() -> void:
	_level_timer_paused = false


func is_level_timer_paused() -> bool:
	return _level_timer_paused


func reset_level_timer_to_full() -> void:
	_level_elapsed_seconds = 0.0
	_time_limit_checked = false
	level_timer_changed.emit(_level_time_limit_seconds, _level_time_limit_seconds)


func start_level_timer_from_full() -> void:
	reset_level_timer_to_full()
	resume_level_timer()


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
	
	AudioGlobal.stop_music()
	AudioGlobal.start_ui_sfx("res://Assets/SFX/Lose.wav", [0.97, 1.02])
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
		SceneTransition.change_scene(current_level_path)
	else:
		get_tree().reload_current_scene()


func _on_next_pressed() -> void:
	get_tree().paused = false
	if current_level_index < LEVEL_SCENES.size():
		go_to_level(current_level_index + 1)
	else:
		go_to_level_selector()


func complete_current_level() -> void:
	_game_over = true
	var next_level := current_level_index + 1
	if next_level > max_unlocked_level:
		max_unlocked_level = min(next_level, LEVEL_SCENES.size())
		_save_progress()
	go_to_level_selector()


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
	SceneTransition.change_scene(LEVEL_SCENES[level_index - 1])


func go_to_level_selector() -> void:
	hide_ui()
	get_tree().paused = false
	SceneTransition.change_scene(LEVEL_SELECTOR_SCENE)


func is_level_unlocked(level_index: int) -> bool:
	return level_index >= 1 and level_index <= max_unlocked_level


func get_max_unlocked_level() -> int:
	return max_unlocked_level


func get_last_level_index() -> int:
	return last_level_index


func _find_level_index_by_scene(scene_path: String) -> int:
	if scene_path == "":
		return current_level_index

	for i in range(LEVEL_SCENES.size()):
		if LEVEL_SCENES[i] == scene_path:
			return i + 1

	var file_name := scene_path.get_file().to_lower()
	if file_name.begins_with("level_") and file_name.ends_with(".tscn"):
		var index_text := file_name.trim_prefix("level_").trim_suffix(".tscn")
		if index_text.is_valid_int():
			var parsed_index := int(index_text)
			if parsed_index >= 1 and parsed_index <= LEVEL_SCENES.size():
				return parsed_index

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
