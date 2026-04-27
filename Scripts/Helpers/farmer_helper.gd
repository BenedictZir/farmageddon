class_name FarmerHelper
extends Helper

## Farmer NPC — automatically manages the farm based on a queue.

@export var scan_interval := 0.5
@export var preferred_feed_crop_name := "parsnip"

var seed_queue: Array[CropData] = []
var _seed_growth_phase_queue: Array[int] = []
var fertilizer_queue: Array[ItemData] = []
var _is_holding_product := false

var held_item: ItemData = null :
	set(value):
		held_item = value
		if helper_visual:
			if value != null:
				var is_fertilizer := value.get_placeable_type() == Placeable.Type.FERTILIZER
				var show_icon := _is_holding_product or is_fertilizer
				helper_visual.set_carrying(true)
				helper_visual.set_carry_no_tool(show_icon)
				if show_icon:
					var held_icon := _resolve_item_icon(value)
					if held_icon:
						helper_visual.show_held_item(held_icon)
					else:
						helper_visual.hide_held_item()
				else:
					helper_visual.hide_held_item()
			else:
				helper_visual.set_carrying(false)
				helper_visual.set_carry_no_tool(false)
				helper_visual.hide_held_item()

const DROPPED_ITEM_SCENE = preload("res://Scenes/Items/dropped_item.tscn")

func _ready() -> void:
	super._ready()
	add_to_group("farmer_helpers")
	add_to_group("helpers")


# ── Search Helpers ──────────────────────────────────────────

func _is_tile_targeted(tile: Node2D) -> bool:
	for f in get_tree().get_nodes_in_group("farmer_helpers"):
		if f != self and f.target_node == tile:
			return true
	return false

func _find_nearest_hungry_animal() -> Node2D:
	var best: Node2D = null
	var best_dist = INF
	for tile in get_tree().get_nodes_in_group("animal_tiles"):
		if tile.is_feedable() and not _is_tile_targeted(tile):
			var dist = global_position.distance_to(tile.global_position)
			if dist < best_dist:
				best_dist = dist
				best = tile
	return best

func _find_nearest_empty_tile() -> Node2D:
	var best: Node2D = null
	var best_dist = INF
	for tile in get_tree().get_nodes_in_group("plantable_tiles"):
		if tile.has_method("accepts_type") \
			and tile.accepts_type(Placeable.Type.CROP) \
			and not _is_tile_targeted(tile):
			var dist = global_position.distance_to(tile.global_position)
			if dist < best_dist:
				best_dist = dist
				best = tile
	return best

func _find_best_fertilize_target() -> Node2D:
	var best: Node2D = null
	var best_score = -1.0
	for tile in get_tree().get_nodes_in_group("plantable_tiles"):
		if tile.has_method("is_fertilizable") and tile.is_fertilizable() and not _is_tile_targeted(tile):
			var score = tile.get_fertilize_score()
			if score > best_score:
				best_score = score
				best = tile
	return best

func _find_nearest_harvest_target() -> Node2D:
	var best: Node2D = null
	var best_dist = INF
	for group in ["plantable_tiles", "animal_tiles"]:
		for tile in get_tree().get_nodes_in_group(group):
			if tile.has_method("is_harvestable") and tile.is_harvestable() and not _is_tile_targeted(tile):
				var dist = global_position.distance_to(tile.global_position)
				if dist < best_dist:
					best_dist = dist
					best = tile
	return best


func _get_dropped_item_candidates() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("hud_occluders"):
		if not (node is Node2D):
			continue
		if not node.has_method("pick_up"):
			continue
		if node.is_in_group("forage_items"):
			continue
		if _is_tile_targeted(node):
			continue
		candidates.append(node)
	return candidates


func _find_nearest_dropped_feed() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for drop in _get_dropped_item_candidates():
		var item := drop.get("item_data") as ItemData
		if not item:
			continue
		if bool(drop.get("was_growing")):
			continue
		if not _is_preferred_feed_item(item):
			continue
		var dist := global_position.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best


func _find_nearest_dropped_fertilizer() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for drop in _get_dropped_item_candidates():
		var item := drop.get("item_data") as ItemData
		if not item:
			continue
		if item.get_placeable_type() != Placeable.Type.FERTILIZER:
			continue
		var dist := global_position.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best


func _find_nearest_dropped_seed() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for drop in _get_dropped_item_candidates():
		if not bool(drop.get("was_growing")):
			continue
		var item := drop.get("item_data") as ItemData
		if not (item is CropData):
			continue
		var dist := global_position.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best


func _find_nearest_dropped_sellable() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for drop in _get_dropped_item_candidates():
		if bool(drop.get("was_growing")):
			continue
		var item := drop.get("item_data") as ItemData
		if not item:
			continue
		if item.get_placeable_type() == Placeable.Type.FERTILIZER:
			continue
		if not _is_sellable_item(item):
			continue
		var dist := global_position.distance_to(drop.global_position)
		if dist < best_dist:
			best_dist = dist
			best = drop
	return best


func _pick_up_dropped_item(drop: Node2D) -> bool:
	if not drop or not drop.has_method("pick_up"):
		return false

	var data: Dictionary = drop.pick_up()
	var item := data.get("item_data") as ItemData
	if not item:
		return false

	var was_growing := bool(data.get("was_growing", false))
	if was_growing and item is CropData:
		seed_queue.push_front(item)
		_seed_growth_phase_queue.push_front(maxi(0, int(data.get("growth_phase", 0))))
		return true

	if _is_preferred_feed_item(item):
		_is_holding_product = true
		held_item = item
		return true

	if item.get_placeable_type() == Placeable.Type.FERTILIZER:
		fertilizer_queue.push_front(item)
		return true

	if _is_sellable_item(item):
		_is_holding_product = true
		held_item = item
		return true

	return false


func _resolve_item_icon(item: ItemData) -> Texture2D:
	if not item:
		return null
	if item.icon:
		return item.icon
	if item.has_method("get_drop_texture"):
		return item.get_drop_texture(0)
	return null


func _is_preferred_feed_item(item: ItemData) -> bool:
	if not item:
		return false
	if not item.has_method("is_animal_feed") or not item.is_animal_feed():
		return false

	var preferred := preferred_feed_crop_name.strip_edges().to_lower()
	if preferred == "":
		return true

	var item_name_lc := item.item_name.to_lower()
	return item_name_lc == preferred


func _is_sellable_item(item: ItemData) -> bool:
	if not item:
		return false
	if item.has_method("is_sellable_product") and item.is_sellable_product():
		return true
	return item.sell_price > 0


# ── Executions ──────────────────────────────────────────

func _execute_plant() -> void:
	if seed_queue.is_empty():
		return
	if not is_instance_valid(target_node):
		return
	var tile := target_node
	if global_position.distance_to(tile.global_position) >= 32.0:
		return
	if not tile.has_method("accepts_type") or not tile.accepts_type(Placeable.Type.CROP):
		return

	var seed = seed_queue.pop_front()
	var growth_phase := 0
	if not _seed_growth_phase_queue.is_empty():
		growth_phase = maxi(0, int(_seed_growth_phase_queue.pop_front()))
	if growth_phase > 0 and tile.has_method("plant_crop_at_phase"):
		tile.plant_crop_at_phase(seed, growth_phase)
	else:
		tile.plant_crop(seed)

func _execute_fertilize() -> void:
	if fertilizer_queue.is_empty():
		return
	var best = _find_best_fertilize_target()
	if best and global_position.distance_to(best.global_position) < 32.0:
		fertilizer_queue.pop_front()
		best.fertilize()
		held_item = null
		_is_holding_product = false

func _execute_harvest() -> void:
	if is_instance_valid(target_node) and target_node.has_method("pick_up"):
		if global_position.distance_to(target_node.global_position) <= 32.0:
			_pick_up_dropped_item(target_node)
		target_node = null
		return

	# Check what tile we are on
	var harvest_target = _find_nearest_harvest_target()
	if not harvest_target or global_position.distance_to(harvest_target.global_position) > 32.0:
		return

	if harvest_target.is_in_group("animal_tiles"):
		var product = harvest_target.harvest_product()
		if product:
			_is_holding_product = true
			held_item = product
	elif harvest_target.is_in_group("plantable_tiles"):
		var crop = harvest_target.harvest_crop()
		if crop:
			_is_holding_product = true
			held_item = crop

func _execute_feed() -> void:
	if not held_item:
		return
	if not _is_preferred_feed_item(held_item):
		_drop_held_item()
		return
	var animal = _find_nearest_hungry_animal()
	if animal and global_position.distance_to(animal.global_position) < 32.0:
		animal.feed_animal()
		_is_holding_product = false
		held_item = null


func _drop_held_item() -> void:
	if not held_item:
		return
	if held_item.get_placeable_type() == Placeable.Type.FERTILIZER:
		if fertilizer_queue.is_empty() or fertilizer_queue[0] != held_item:
			fertilizer_queue.push_front(held_item)
		held_item = null
		_is_holding_product = false
		return
	_spawn_drop(held_item, global_position, _is_holding_product)
	held_item = null
	_is_holding_product = false

func _spawn_drop(item: ItemData, pos: Vector2, force_product := false) -> void:
	if not item:
		return

	var treat_as_product := force_product or _is_holding_product
	var icon_tex: Texture2D = null
	if treat_as_product and item.has_method("is_sellable_product") and item.is_sellable_product():
		icon_tex = _resolve_item_icon(item)
		
	var drop = DROPPED_ITEM_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = pos
	drop.setup({
		"item_data": item,
		"was_growing": not treat_as_product,
		"growth_phase": 0,
		"icon": icon_tex
	})


# ── Public APIs ──────────────────────────────────────────

func add_seed_to_queue(crop: CropData) -> void:
	seed_queue.append(crop)
	_seed_growth_phase_queue.append(0)

func add_fertilizer(item: ItemData) -> void:
	fertilizer_queue.append(item)
