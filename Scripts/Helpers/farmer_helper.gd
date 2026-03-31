class_name FarmerHelper
extends Helper

## Farmer NPC — automatically manages the farm based on a queue.

@export var scan_interval := 0.5

var seed_queue: Array[CropData] = []
var fertilizer_queue: Array[ItemData] = []
var _is_holding_product := false

var held_item: ItemData = null :
	set(value):
		held_item = value
		if helper_visual:
			if value != null:
				# Seeds use tool animation, harvested products use carry_no_tool
				var is_seed = not _is_holding_product
				helper_visual.set_carrying(true)
				helper_visual.set_carry_no_tool(not is_seed)
				if is_seed:
					helper_visual.hide_held_item()
				else:
					helper_visual.show_held_item(value.icon)
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


# ── Executions ──────────────────────────────────────────

func _execute_plant() -> void:
	if seed_queue.is_empty():
		return
	var tile = _find_nearest_empty_tile()
	# The tile we walked to might have been planted by the player manually. Re-check distance.
	if tile and global_position.distance_to(tile.global_position) < 32.0:
		var seed = seed_queue.pop_front()
		tile.plant_crop(seed)

func _execute_fertilize() -> void:
	if fertilizer_queue.is_empty():
		return
	var best = _find_best_fertilize_target()
	if best and global_position.distance_to(best.global_position) < 32.0:
		fertilizer_queue.pop_front()
		best.fertilize()

func _execute_harvest() -> void:
	# Check what tile we are on
	var harvest_target = _find_nearest_harvest_target()
	if not harvest_target or global_position.distance_to(harvest_target.global_position) > 32.0:
		return

	if harvest_target.is_in_group("animal_tiles"):
		var product = harvest_target.harvest_product()
		_spawn_drop(product, harvest_target.global_position)
	elif harvest_target.is_in_group("plantable_tiles"):
		var crop = harvest_target.harvest_crop()
		if crop and crop.has_method("is_animal_feed") and crop.is_animal_feed():
			_is_holding_product = true
			held_item = crop
			# Holding a crop triggers Priority 1 next tick

func _execute_feed() -> void:
	if not held_item:
		return
	var animal = _find_nearest_hungry_animal()
	if animal and global_position.distance_to(animal.global_position) < 32.0:
		animal.feed_animal()
		_is_holding_product = false
		held_item = null


func _drop_held_item() -> void:
	if not held_item:
		return
	_spawn_drop(held_item, global_position)
	held_item = null

func _spawn_drop(item: ItemData, pos: Vector2) -> void:
	var icon_tex: Texture2D = null
	if _is_holding_product and item.has_method("is_sellable_product") and item.is_sellable_product():
		icon_tex = item.icon
		
	var drop = DROPPED_ITEM_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = pos
	drop.setup({
		"item_data": item,
		"was_growing": not _is_holding_product,
		"growth_phase": 0,
		"icon": icon_tex
	})


# ── Public APIs ──────────────────────────────────────────

func add_seed_to_queue(crop: CropData) -> void:
	seed_queue.append(crop)

func add_fertilizer(item: ItemData) -> void:
	fertilizer_queue.append(item)
