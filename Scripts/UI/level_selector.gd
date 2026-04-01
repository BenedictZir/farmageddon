extends Control
class_name LevelSelector

@onready var level_1_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/Level1Button
@onready var level_2_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/Level2Button
@onready var level_3_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/Level3Button
@onready var level_4_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/Level4Button

var _buttons: Array[Button] = []


func _ready() -> void:
	_buttons = [level_1_button, level_2_button, level_3_button, level_4_button]

	for i in range(_buttons.size()):
		var level_index := i + 1
		var button := _buttons[i]
		button.text = "LEVEL %d" % level_index
		button.pressed.connect(_on_level_pressed.bind(level_index))

	if GameManager.has_signal("progress_changed") and not GameManager.progress_changed.is_connected(_on_progress_changed):
		GameManager.progress_changed.connect(_on_progress_changed)

	_refresh_buttons()


func _on_progress_changed(_max_unlocked_level: int, _last_level_index: int) -> void:
	_refresh_buttons()


func _refresh_buttons() -> void:
	var max_unlocked := GameManager.get_max_unlocked_level()
	for i in range(_buttons.size()):
		var level_index := i + 1
		var button := _buttons[i]
		var unlocked := level_index <= max_unlocked
		button.disabled = not unlocked
		button.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.35, 1.0)


func _on_level_pressed(level_index: int) -> void:
	GameManager.go_to_level(level_index)
