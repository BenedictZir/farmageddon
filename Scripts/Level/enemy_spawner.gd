extends Node2D
class_name EnemySpawner

## Spawns enemies from the edges of the map based on LevelData waves over time.

signal enemy_spawned(enemy: Node2D)

@export var level_data: LevelData
@export var warning_inset := 6.0
@export var warning_screen_margin := 16.0
@export var warning_fade_in := 0.16
@export var warning_hold := 0.5
@export var warning_fade_out := 0.2
@export var warning_peak_alpha := 0.95
@export var warning_base_scale := Vector2(0.72, 0.72)
@export var warning_peak_scale := Vector2(2.0, 2.0)

const WARNING_TEXTURE_PATH := "res://Assets/Violating.png"
const WARNING_LAYER_NAME := "SpawnWarningOverlay"
const WARNING_LAYER_INDEX := 80

var _level_timer := 0.0
var _spawn_timer := 0.0
var _current_wave: WaveData = null
var _wave_index := -1
var _warning_texture: Texture2D
var _warning_layer: CanvasLayer

func _ready() -> void:
	_warning_texture = load(WARNING_TEXTURE_PATH) as Texture2D
	_warning_layer = _get_or_create_warning_layer()

	if not level_data or level_data.waves.is_empty():
		set_process(false)
		return
	
	# Ensure waves are sorted chronologically
	level_data.waves.sort_custom(func(a: WaveData, b: WaveData):
		return a.start_time_seconds < b.start_time_seconds
	)
	
	_advance_wave()
	call_deferred("_apply_tutorial_process_gate")


func _apply_tutorial_process_gate() -> void:
	if GameManager.tutorial_active:
		set_process(false)


func start_from_tutorial() -> void:
	set_process(true)
	if not _current_wave or _current_wave.allowed_enemies.is_empty():
		return

	var spawn_interval := _current_wave.spawn_interval * GameManager.get_enemy_spawn_interval_multiplier()
	spawn_interval = maxf(0.05, spawn_interval)
	_spawn_timer = maxf(0.0, spawn_interval - 2.0) # Spawn 2 seconds after the tutorial calls start


func pause_from_tutorial() -> void:
	set_process(false)


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
		var spawn_interval := _current_wave.spawn_interval * GameManager.get_enemy_spawn_interval_multiplier()
		spawn_interval = maxf(0.05, spawn_interval)
		while _spawn_timer >= spawn_interval:
			_spawn_timer -= spawn_interval
			_spawn_enemy()


func _advance_wave() -> void:
	_wave_index += 1
	_current_wave = level_data.waves[_wave_index]
	_spawn_timer = 0.0 # Reset spawn timer when new wave hits
	# Optionally, trigger a signal here for "Wave started" UI!


func _spawn_enemy() -> void:
	var enemy_instance: Node2D = null
	var has_planted_crop := _has_any_planted_crop()
	var candidates: Array[PackedScene] = _current_wave.allowed_enemies.duplicate()
	candidates.shuffle()

	for enemy_scene in candidates:
		if not enemy_scene:
			continue

		var candidate := enemy_scene.instantiate() as Node2D
		if not candidate:
			continue

		# If Bird is selected with no crop available, try another enemy in this wave.
		if candidate is Bird and not has_planted_crop:
			candidate.queue_free()
			continue

		enemy_instance = candidate
		break

	if not enemy_instance:
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

	_show_spawn_warning(side, extents, spawn_pos)

	get_parent().add_child(enemy_instance) # Add to the Level root
	enemy_instance.global_position = spawn_pos
	enemy_spawned.emit(enemy_instance)


func _has_any_planted_crop() -> bool:
	for tile in get_tree().get_nodes_in_group("plantable_tiles"):
		if tile.has_method("has_planted_crop") and tile.has_planted_crop():
			return true

	# Fallback for older tile implementations.
	for tile in get_tree().get_nodes_in_group("plantable_tiles"):
		if tile.get("placed_crop") != null:
			return true

	return false


func _show_spawn_warning(side: int, extents: Vector2, spawn_pos: Vector2) -> void:
	if not _warning_texture:
		return
	if not _warning_layer or not is_instance_valid(_warning_layer):
		_warning_layer = _get_or_create_warning_layer()
	if not _warning_layer:
		return

	var warning := Sprite2D.new()
	warning.texture = _warning_texture
	warning.z_index = 1
	warning.scale = warning_base_scale
	warning.modulate = Color(1.0, 1.0, 1.0, 0.0)
	warning.position = _get_warning_screen_position(side, extents, spawn_pos)

	_warning_layer.add_child(warning)

	var tween := create_tween()
	tween.tween_property(warning, "modulate:a", warning_peak_alpha, warning_fade_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(warning, "scale", warning_peak_scale, warning_fade_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(warning_hold)
	tween.tween_property(warning, "modulate:a", 0.0, warning_fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(warning, "scale", warning_base_scale * 0.9, warning_fade_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(warning.queue_free)


func _get_warning_screen_position(side: int, extents: Vector2, spawn_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if not viewport:
		return _get_warning_world_position_fallback(side, extents, spawn_pos)

	var screen_rect := viewport.get_visible_rect()
	if screen_rect.size.x <= 0.0 or screen_rect.size.y <= 0.0:
		return _get_warning_world_position_fallback(side, extents, spawn_pos)

	var screen_pos := viewport.get_canvas_transform() * spawn_pos
	var margin := maxf(10.0, warning_screen_margin)
	var min_x := margin
	var max_x := screen_rect.size.x - margin
	var min_y := margin
	var max_y := screen_rect.size.y - margin

	if max_x <= min_x:
		min_x = 0.0
		max_x = screen_rect.size.x
	if max_y <= min_y:
		min_y = 0.0
		max_y = screen_rect.size.y

	match side:
		0: # Top
			return Vector2(clampf(screen_pos.x, min_x, max_x), min_y)
		1: # Bottom
			return Vector2(clampf(screen_pos.x, min_x, max_x), max_y)
		2: # Left
			return Vector2(min_x, clampf(screen_pos.y, min_y, max_y))
		3: # Right
			return Vector2(max_x, clampf(screen_pos.y, min_y, max_y))

	return Vector2(clampf(screen_pos.x, min_x, max_x), clampf(screen_pos.y, min_y, max_y))


func _get_warning_world_position_fallback(side: int, extents: Vector2, spawn_pos: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.is_inside_tree():
		var visible_size := get_viewport().get_visible_rect().size * camera.zoom
		var top_left := camera.get_screen_center_position() - (visible_size * 0.5)
		var bottom_right := top_left + visible_size
		var margin := maxf(2.0, warning_screen_margin)

		match side:
			0: # Top
				return Vector2(clampf(spawn_pos.x, top_left.x + margin, bottom_right.x - margin), top_left.y + margin)
			1: # Bottom
				return Vector2(clampf(spawn_pos.x, top_left.x + margin, bottom_right.x - margin), bottom_right.y - margin)
			2: # Left
				return Vector2(top_left.x + margin, clampf(spawn_pos.y, top_left.y + margin, bottom_right.y - margin))
			3: # Right
				return Vector2(bottom_right.x - margin, clampf(spawn_pos.y, top_left.y + margin, bottom_right.y - margin))

	# Fallback if camera is unavailable.
	match side:
		0: # Top
			return Vector2(clampf(spawn_pos.x, -extents.x, extents.x), -extents.y + warning_inset)
		1: # Bottom
			return Vector2(clampf(spawn_pos.x, -extents.x, extents.x), extents.y - warning_inset)
		2: # Left
			return Vector2(-extents.x + warning_inset, clampf(spawn_pos.y, -extents.y, extents.y))
		3: # Right
			return Vector2(extents.x - warning_inset, clampf(spawn_pos.y, -extents.y, extents.y))

	return spawn_pos


func _get_or_create_warning_layer() -> CanvasLayer:
	var root := get_tree().current_scene
	if not root:
		return null

	var existing := root.get_node_or_null(WARNING_LAYER_NAME) as CanvasLayer
	if existing:
		return existing

	var layer := CanvasLayer.new()
	layer.name = WARNING_LAYER_NAME
	layer.layer = WARNING_LAYER_INDEX
	root.add_child(layer)
	return layer
