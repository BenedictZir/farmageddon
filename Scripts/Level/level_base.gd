extends Node2D
class_name LevelBase

## The base root of every farm level.
## It configures its own Map Bounds and registers with the GameManager.

@export var map_extents := Vector2(170, 105)


func _ready() -> void:
	# Register the current boundaries so Goblin AI and game systems know
	GameManager.register_level(map_extents, scene_file_path)
