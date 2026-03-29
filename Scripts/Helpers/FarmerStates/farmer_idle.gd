extends State

## FarmerIdle: Roam slowly while scanning for work. Never stops abruptly.

var _scan_timer := 0.0
var _roam_timer := 0.0
var _roam_dir := Vector2.RIGHT

func enter() -> void:
	super()
	_scan_timer = 0.0
	_roam_timer = 0.0
	_roam_dir = Vector2.from_angle(randf_range(0, TAU))

func physics_update(delta: float) -> void:
	# Scan for work
	_scan_timer += delta
	if _scan_timer >= entity.scan_interval:
		_scan_timer = 0.0
		_find_work()
	
	# Change direction periodically
	_roam_timer -= delta
	if _roam_timer <= 0.0:
		_roam_timer = randf_range(3.0, 6.0)
		_roam_dir = _pick_random_dir()
	
	# Clamp inside map to avoid fence collisions
	var extents = GameManager.map_extents
	var padding := 30.0
	var clamped_pos = Vector2(
		clampf(entity.global_position.x, -extents.x + padding, extents.x - padding),
		clampf(entity.global_position.y, -extents.y + padding, extents.y - padding)
	)
	if clamped_pos != entity.global_position:
		# We hit the edge: pick a direction toward center
		_roam_dir = (Vector2.ZERO - entity.global_position).normalized()
	
	entity.movement_component.move(entity, _roam_dir, false)
	entity.helper_visual.update_movement_anim(_roam_dir, false)

func _pick_random_dir() -> Vector2:
	return Vector2.from_angle(randf_range(0, TAU))

func _find_work() -> void:
	if entity.held_item != null:
		var hungry_animal = entity._find_nearest_hungry_animal()
		if hungry_animal:
			entity.target_node = hungry_animal
			transition.emit("feed")
		else:
			entity._drop_held_item()
		return

	if entity.seed_queue.size() > 0:
		var empty_tile = entity._find_nearest_empty_tile()
		if empty_tile:
			entity.target_node = empty_tile
			transition.emit("plant")
			return

	if entity.fertilizer_queue.size() > 0:
		var tile_to_fertilize = entity._find_best_fertilize_target()
		if tile_to_fertilize:
			entity.target_node = tile_to_fertilize
			transition.emit("fertilize")
			return

	var harvest_target = entity._find_nearest_harvest_target()
	if harvest_target:
		entity.target_node = harvest_target
		transition.emit("harvest")
		return
