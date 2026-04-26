extends CanvasLayer

## Pause screen with control hints.
## Toggle with ESC. Shows animated player demos + key prompts for each action.

@onready var blur_rect: ColorRect = $BlurRect
@onready var panel: Control = $Panel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

var _is_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	visible = false
	continue_button.pressed.connect(_unpause)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if GameManager.tutorial_active and not GameManager.is_input_unlocked("ui_cancel"):
		return

	if _is_paused:
		_unpause()
	else:
		_pause()
	get_viewport().set_input_as_handled()


func _pause() -> void:
	if GameManager._game_over:
		return
	AudioGlobal.start_ui_sfx("res://Assets/SFX/Pause.wav", [0.97, 1.02], -2)
	_is_paused = true
	visible = true
	get_tree().paused = true
	# Start all player preview animations
	_play_all_previews()


func _unpause() -> void:
	_is_paused = false
	visible = false
	get_tree().paused = false


func _play_all_previews() -> void:
	# Find all AnimatedSprite2D children named "PlayerPreview" and play them
	for node in _get_all_children(panel):
		if node is AnimatedSprite2D and node.name.begins_with("PlayerPreview"):
			node.play()




func _get_all_children(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_children(child))
	return result


func _on_level_button_pressed() -> void:
	_unpause()
	SceneTransition.change_scene("res://Scenes/UI/level_selector.tscn")
