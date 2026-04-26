extends Control

func _ready() -> void:
	AudioGlobal.play_music("res://Assets/Music/menu_music.wav", -12)
func _on_play_button_pressed() -> void:
	SceneTransition.change_scene("res://Scenes/UI/level_selector.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
