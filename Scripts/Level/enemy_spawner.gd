extends Node2D
class_name EnemySpawner

## Spawns enemies from the edges of the map based on LevelData waves over time.

@export var level_data: LevelData

var _level_timer := 0.0
var _spawn_timer := 0.0
var _current_wave: WaveData = null
var _wave_index := -1

func _ready() -> void:
	if not level_data or level_data.waves.is_empty():
		set_process(false)
		return
	
	# Ensure waves are sorted chronologically
	level_data.waves.sort_custom(func(a: WaveData, b: WaveData):
		return a.start_time_seconds < b.start_time_seconds
	)
	
	_advance_wave()


func _process(delta: float) -> void:
	if GameManager._game_over:
		return
		
	_level_timer += delta
	_spawn_timer += delta
	
	# Check if we should advance to the next wave
	if _wave_index + 1 < level_data.waves.size():
		var next_wave = level_data.waves[_wave_index + 1]
		if _level_timer >= next_wave.start_time_seconds:
			_advance_wave()
			
	# Process Spawning
	if _current_wave and not _current_wave.allowed_enemies.is_empty():
		if _spawn_timer >= _current_wave.spawn_interval:
			_spawn_timer -= _current_wave.spawn_interval
			_spawn_enemy()


func _advance_wave() -> void:
	_wave_index += 1
	_current_wave = level_data.waves[_wave_index]
	_spawn_timer = 0.0 # Reset spawn timer when new wave hits
	# Optionally, trigger a signal here for "Wave started" UI!


func _spawn_enemy() -> void:
	var enemy_scene: PackedScene = _current_wave.allowed_enemies.pick_random()
	if not enemy_scene:
		return
		
	var extents := GameManager.map_extents
	var side = randi() % 4
	var spawn_pos := Vector2.ZERO
	
	match side:
		0: # Top
			spawn_pos = Vector2(randf_range(-extents.x, extents.x), -extents.y - 20)
		1: # Bottom
			spawn_pos = Vector2(randf_range(-extents.x, extents.x), extents.y + 20)
		2: # Left
			spawn_pos = Vector2(-extents.x - 20, randf_range(-extents.y, extents.y))
		3: # Right
			spawn_pos = Vector2(extents.x + 20, randf_range(-extents.y, extents.y))
			
	var enemy_instance = enemy_scene.instantiate() as Node2D
	get_parent().add_child(enemy_instance) # Add to the Level root
	enemy_instance.global_position = spawn_pos
