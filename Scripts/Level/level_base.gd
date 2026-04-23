extends Node2D
class_name LevelBase

## The base root of every farm level.
## It configures its own Map Bounds and registers with the GameManager.

@export var map_extents := Vector2(170, 105)
@export var level_data: LevelData

@export_group("Level Intro Transition")
@export var play_level_intro_transition := false
@export var intro_camera_path: NodePath = NodePath("Camera2D")
@export var intro_zoom_start := Vector2(2.6, 2.6)
@export var intro_zoom_end := Vector2(2.0, 2.0)
@export var intro_zoom_duration := 1.2

@export_group("Fence Build")
@export var animate_fence_build := true
@export var old_fence_layer_path: NodePath = NodePath("")
@export var new_fence_layer_path: NodePath = NodePath("Fences")
@export var fence_build_duration := 1.4
@export var fence_drop_height := 26.0
@export var fence_drop_time := 0.45
@export_range(0.05, 0.95, 0.05) var fence_wave_interval_ratio := 0.4

@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var timer_label: Label = $UI/TimerLabel
@onready var gold_label: GoldCounterLabel = $UI/GoldLabel
@onready var level_camera: Camera2D = get_node_or_null(intro_camera_path) as Camera2D

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
		spawner.name = "EnemySpawner"
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

	var old_layer := _resolve_fence_layer(old_fence_layer_path)
	var new_layer := _resolve_fence_layer(new_fence_layer_path)
	var has_transition_layers := old_layer and new_layer and old_layer != new_layer
	if has_transition_layers:
		new_layer.visible = false

	if play_level_intro_transition or animate_fence_build or has_transition_layers:
		call_deferred("_play_level_intro_sequence")


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


func _play_level_intro_sequence() -> void:
	var old_layer := _resolve_fence_layer(old_fence_layer_path)
	var new_layer := _resolve_fence_layer(new_fence_layer_path)
	var has_transition_layers := old_layer and new_layer and old_layer != new_layer
	var zoom_tween: Tween = null

	if play_level_intro_transition:
		zoom_tween = _start_intro_zoom_tween()

	if has_transition_layers:
		await _play_fence_clear_animation(old_layer)
		new_layer.visible = true
		await _play_fence_build_animation(new_layer)
	elif animate_fence_build and new_layer:
		await _play_fence_build_animation(new_layer)

	if zoom_tween:
		await zoom_tween.finished


func _start_intro_zoom_tween() -> Tween:
	if not level_camera:
		return null

	level_camera.zoom = intro_zoom_start
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(level_camera, "zoom", intro_zoom_end, clampf(intro_zoom_duration, 0.1, 3.0))\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _resolve_fence_layer(path: NodePath) -> TileMapLayer:
	if path == NodePath(""):
		return null
	return get_node_or_null(path) as TileMapLayer


func _play_fence_build_animation(layer: TileMapLayer) -> void:
	await _play_fence_layer_animation(layer, false)


func _play_fence_clear_animation(layer: TileMapLayer) -> void:
	await _play_fence_layer_animation(layer, true)


func _play_fence_layer_animation(layer: TileMapLayer, reverse_order: bool) -> void:
	if not layer:
		return

	var fence_cells: Array[Vector2i] = layer.get_used_cells()
	if fence_cells.is_empty():
		return

	var cell_data := {}
	var center := Vector2.ZERO
	for cell in fence_cells:
		center += Vector2(cell)
		cell_data[cell] = {
			"source_id": layer.get_cell_source_id(cell),
			"atlas_coords": layer.get_cell_atlas_coords(cell),
			"alternative_tile": layer.get_cell_alternative_tile(cell),
		}

	center /= float(fence_cells.size())

	if not reverse_order:
		for cell in fence_cells:
			layer.erase_cell(cell)

	var ordered_cells := _sort_fence_cells_clockwise(fence_cells, center)
	if ordered_cells.is_empty():
		return

	var start_idx := _find_top_center_fence_index(ordered_cells, center.x)
	var waves := _build_fence_waves(ordered_cells, start_idx)
	if waves.is_empty():
		return

	var wave_count := waves.size()
	var duration := clampf(fence_build_duration, 0.2, 2.0)
	var step_delay := duration / float(maxi(1, wave_count - 1))
	var drop_time := clampf(fence_drop_time, 0.12, 1.2)
	var overlap_delay_cap := drop_time * clampf(fence_wave_interval_ratio, 0.05, 0.95)
	if wave_count > 1:
		step_delay = minf(step_delay, overlap_delay_cap)
	else:
		step_delay = 0.0

	if reverse_order:
		for wave_idx in range(wave_count - 1, -1, -1):
			var wave_cells: Array = waves[wave_idx]
			for cell in wave_cells:
				_lift_fence_cell(layer, cell, cell_data, drop_time)

			if wave_idx > 0:
				await get_tree().create_timer(step_delay).timeout
	else:
		for wave_idx in wave_count:
			var wave_cells: Array = waves[wave_idx]
			for cell in wave_cells:
				_place_fence_cell(layer, cell, cell_data, drop_time)

			if wave_idx < wave_count - 1:
				await get_tree().create_timer(step_delay).timeout


func _build_fence_waves(ordered_cells: Array[Vector2i], start_idx: int) -> Array:
	var waves: Array = []
	var used := {}
	var total_cells := ordered_cells.size()
	var offset := 0

	while used.size() < total_cells and offset < total_cells:
		var idx_cw := (start_idx + offset) % total_cells
		var idx_ccw := posmod(start_idx - offset, total_cells)

		var wave: Array[Vector2i] = []

		var cell_cw := ordered_cells[idx_cw]
		if not used.has(cell_cw):
			used[cell_cw] = true
			wave.append(cell_cw)

		var cell_ccw := ordered_cells[idx_ccw]
		if not used.has(cell_ccw):
			used[cell_ccw] = true
			wave.append(cell_ccw)

		if not wave.is_empty():
			waves.append(wave)

		offset += 1

	return waves


func _sort_fence_cells_clockwise(cells: Array[Vector2i], center: Vector2) -> Array[Vector2i]:
	var decorated: Array = []

	for cell in cells:
		var dir := Vector2(cell) - center
		var angle := fposmod(atan2(dir.y, dir.x) + PI * 0.5, TAU)
		var dist := dir.length_squared()
		decorated.append({
			"cell": cell,
			"angle": angle,
			"dist": dist,
		})

	decorated.sort_custom(func(a, b):
		if is_equal_approx(a["angle"], b["angle"]):
			return a["dist"] < b["dist"]
		return a["angle"] < b["angle"]
	)

	var ordered: Array[Vector2i] = []
	for entry in decorated:
		ordered.append(entry["cell"])

	return ordered


func _find_top_center_fence_index(cells: Array[Vector2i], center_x: float) -> int:
	var best_idx := 0
	var best_y := 1 << 30
	var best_dx := INF

	for i in cells.size():
		var cell := cells[i]
		var dx := absf(float(cell.x) - center_x)

		if cell.y < best_y:
			best_y = cell.y
			best_dx = dx
			best_idx = i
		elif cell.y == best_y and dx < best_dx:
			best_dx = dx
			best_idx = i

	return best_idx


func _place_fence_cell(layer: TileMapLayer, cell: Vector2i, cell_data: Dictionary, drop_time: float) -> void:
	var data: Dictionary = cell_data.get(cell, {})
	if data.is_empty():
		return

	var source_id := int(data.get("source_id", -1))
	if source_id == -1:
		return

	var atlas_coords: Vector2i = data.get("atlas_coords", Vector2i(-1, -1))
	var alternative_tile := int(data.get("alternative_tile", 0))

	var temp_layer := _create_temp_fence_layer(layer)
	temp_layer.position = Vector2(0.0, -absf(fence_drop_height))
	temp_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(temp_layer, "position:y", 0.0, drop_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		layer.set_cell(cell, source_id, atlas_coords, alternative_tile)
		if is_instance_valid(temp_layer):
			temp_layer.queue_free()
	)


func _lift_fence_cell(layer: TileMapLayer, cell: Vector2i, cell_data: Dictionary, drop_time: float) -> void:
	var data: Dictionary = cell_data.get(cell, {})
	if data.is_empty():
		return

	var source_id := int(data.get("source_id", -1))
	if source_id == -1:
		return

	var atlas_coords: Vector2i = data.get("atlas_coords", Vector2i(-1, -1))
	var alternative_tile := int(data.get("alternative_tile", 0))

	layer.erase_cell(cell)

	var temp_layer := _create_temp_fence_layer(layer)
	temp_layer.set_cell(cell, source_id, atlas_coords, alternative_tile)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(temp_layer, "position:y", -absf(fence_drop_height), drop_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(temp_layer, "modulate:a", 0.0, drop_time)
	tween.tween_callback(func():
		if is_instance_valid(temp_layer):
			temp_layer.queue_free()
	)


func _create_temp_fence_layer(layer: TileMapLayer) -> TileMapLayer:
	var temp_layer := TileMapLayer.new()
	temp_layer.tile_set = layer.tile_set
	temp_layer.y_sort_enabled = layer.y_sort_enabled
	temp_layer.collision_enabled = false
	temp_layer.navigation_enabled = false
	temp_layer.occlusion_enabled = false
	temp_layer.z_index = layer.z_index + 1
	layer.add_child(temp_layer)
	return temp_layer
