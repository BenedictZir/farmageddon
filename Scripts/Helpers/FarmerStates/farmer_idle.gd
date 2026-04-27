extends State

## FarmerIdle: Roam slowly while scanning for work. Never stops abruptly.

var _scan_timer := 0.0
var _roam_timer := 0.0
var _roam_dir := Vector2.RIGHT

const SELLABLE_DROP_TO_PLAYER_RANGE := 26.0

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


func _has_pending_non_delivery_work() -> bool:
	var hungry_animal = entity._find_nearest_hungry_animal()
	if hungry_animal and entity._find_nearest_dropped_feed():
		return true

	var empty_tile = entity._find_nearest_empty_tile()
	if entity.seed_queue.size() > 0 and empty_tile:
		return true
	if empty_tile and entity._find_nearest_dropped_seed():
		return true

	var fertilize_target = entity._find_best_fertilize_target()
	if entity.fertilizer_queue.size() > 0 and fertilize_target:
		return true
	if fertilize_target and entity._find_nearest_dropped_fertilizer():
		return true

	return entity._find_nearest_harvest_target() != null


func _try_drop_sellable_near_player() -> bool:
	var player = PlayerRef.instance
	if not player or not is_instance_valid(player):
		entity._drop_held_item()
		return true

	var to_player = player.global_position - entity.global_position
	if to_player.length() > SELLABLE_DROP_TO_PLAYER_RANGE:
		_roam_dir = to_player.normalized()
		_roam_timer = maxf(_roam_timer, entity.scan_interval + 0.1)
		return true

	entity._drop_held_item()
	return true

func _find_work() -> void:
	if entity.held_item != null:
		var held_type = entity.held_item.get_placeable_type()
		if held_type == Placeable.Type.FERTILIZER:
			var tile_to_fertilize_held = entity._find_best_fertilize_target()
			if tile_to_fertilize_held:
				entity.target_node = tile_to_fertilize_held
				transition.emit("fertilize")
			else:
				entity._drop_held_item()
			return

		var hungry_animal = entity._find_nearest_hungry_animal()
		if entity._is_preferred_feed_item(entity.held_item) and hungry_animal:
			entity.target_node = hungry_animal
			transition.emit("feed")
			return

		if entity._is_sellable_item(entity.held_item):
			if _has_pending_non_delivery_work():
				entity._drop_held_item()
			else:
				_try_drop_sellable_near_player()
			return

		entity._drop_held_item()
		return

	var hungry_animal = entity._find_nearest_hungry_animal()
	if hungry_animal:
		var dropped_feed = entity._find_nearest_dropped_feed()
		if dropped_feed:
			entity.target_node = dropped_feed
			transition.emit("harvest")
			return

	if entity.seed_queue.size() > 0:
		var empty_tile = entity._find_nearest_empty_tile()
		if empty_tile:
			entity.target_node = empty_tile
			transition.emit("plant")
			return

	var empty_tile_for_drop = entity._find_nearest_empty_tile()
	if empty_tile_for_drop:
		var dropped_seed = entity._find_nearest_dropped_seed()
		if dropped_seed:
			entity.target_node = dropped_seed
			transition.emit("harvest")
			return

	if entity.fertilizer_queue.size() > 0:
		var tile_to_fertilize = entity._find_best_fertilize_target()
		if tile_to_fertilize:
			entity.target_node = tile_to_fertilize
			transition.emit("fertilize")
			return

	var tile_to_fertilize_from_drop = entity._find_best_fertilize_target()
	if tile_to_fertilize_from_drop:
		var dropped_fertilizer = entity._find_nearest_dropped_fertilizer()
		if dropped_fertilizer:
			entity.target_node = dropped_fertilizer
			transition.emit("harvest")
			return

	var harvest_target = entity._find_nearest_harvest_target()
	if harvest_target:
		entity.target_node = harvest_target
		transition.emit("harvest")
		return

	var dropped_sellable = entity._find_nearest_dropped_sellable()
	if dropped_sellable:
		entity.target_node = dropped_sellable
		transition.emit("harvest")
		return
