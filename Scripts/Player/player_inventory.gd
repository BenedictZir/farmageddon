extends Node
class_name PlayerInventory

## Manages what the player carries: seeds, harvested crops, items.
## Handles placing, harvesting, selling, and dropping.

var select_box: Node2D
var player_visual: Node2D
var player: CharacterBody2D

var is_carrying := false
var _held_item: ItemData = null
var _held_growth_phase := 0
var _target_tile: Node2D = null
var _is_holding_product := false


func setup(p_player: CharacterBody2D, p_select_box: Node2D, p_visual: Node2D) -> void:
	player = p_player
	select_box = p_select_box
	player_visual = p_visual


# ── Public API ───────────────────────────────────────────

func interact() -> void:
	if !select_box.current_target: # dont play any anim if no target
		return
	if is_carrying and _held_item:
		if _is_holding_product:
			_try_use_product()
		else:
			_try_place_item()
	else:
		_try_harvest()


func drop() -> void:
	if is_carrying and _held_item:
		var dropped_scene := preload("res://Scenes/Items/dropped_item.tscn")
		var item := dropped_scene.instantiate()
		player.get_parent().add_child(item)
		item.global_position = player.global_position
		
		var icon_tex: Texture2D = null
		if _is_holding_product and _held_item.has_method("is_sellable_product") and _held_item.is_sellable_product():
			icon_tex = _held_item.icon
			
		item.setup({
			"item_data": _held_item,
			"was_growing": not _is_holding_product,
			"growth_phase": _held_growth_phase,
			"icon": icon_tex
		})
		_clear()


func hold_item(item: Resource, item_size := Vector2i(1, 1)) -> void:
	_held_item = item as ItemData
	_held_growth_phase = 0
	_is_holding_product = false
	is_carrying = true
	select_box.set_size(item_size)
	_update_carry_visual()


func get_held_item() -> Resource:
	return _held_item


func is_holding_product() -> bool:
	return _is_holding_product


# ── Placing (item → tile) ────────────────────────────────

func _try_place_item() -> void:
	var tile = select_box.current_target
	if not tile:
		return
	var ptype = _held_item.get_placeable_type()
	if ptype >= 0 and tile.has_method("accepts_type") and tile.accepts_type(ptype):
		_target_tile = tile
		if ptype == Placeable.Type.CROP:
			player.velocity = Vector2.ZERO
			player_visual.play_dig()
		else:
			player_visual.play_doing()
			player.velocity = Vector2.ZERO
	else:
		select_box.play_error()


# ── Harvesting (tile → carry) ────────────────────────────

func _try_harvest() -> void:
	var target = select_box.current_target
	if not target:
		player_visual.play_doing()
		return
	if target.has_method("is_harvestable") and target.is_harvestable():
		_target_tile = target
		player.velocity = Vector2.ZERO
		player_visual.play_doing()


func finish_harvest() -> void:
	if not _target_tile:
		return
	var harvested: ItemData = null
	if _target_tile.has_method("harvest_crop"):
		harvested = _target_tile.harvest_crop()
	elif _target_tile.has_method("harvest_product"):
		harvested = _target_tile.harvest_product()
	if not harvested:
		return
	_target_tile = null
	_held_item = harvested
	_is_holding_product = true
	is_carrying = true
	select_box.set_size(Vector2i(1, 1))
	player_visual.set_carry_no_tool(true)
	player_visual.show_held_item(harvested.icon)


# ── Using product (sell / feed animal) ───────────────────

func _try_use_product() -> void:
	var target = select_box.current_target
	# Check if we can feed an animal
	if target and target.has_method("is_feedable") and target.is_feedable() and _held_item.is_animal_feed():
		_target_tile = target
		player.velocity = Vector2.ZERO
		player_visual.play_doing()
		return
	# Otherwise sell
	if _held_item.has_method("is_sellable_product") and _held_item.is_sellable_product():
		_sell_held_item()


func _sell_held_item() -> void:
	if _held_item.sell_price > 0:
		CurrencyManager.add_gold(_held_item.sell_price)
	select_box.play_placing()
	_clear()


func on_interact_anim_finished() -> void:
	if not _target_tile:
		return
	if _held_item and not _is_holding_product:
		# Was placing an item on a tile
		var ptype = _held_item.get_placeable_type()
		if ptype == Placeable.Type.CROP:
			if _held_growth_phase > 0 and _target_tile.has_method("plant_crop_at_phase"):
				_target_tile.plant_crop_at_phase(_held_item, _held_growth_phase)
			else:
				_target_tile.plant_crop(_held_item)
		elif ptype == Placeable.Type.FERTILIZER:
			_target_tile.fertilize()
		elif ptype == Placeable.Type.ANIMAL:
			if _target_tile.has_method("place_animal"):
				_target_tile.place_animal(_held_item)
		select_box.play_placing()
		_clear()
		
	elif _is_holding_product:
		# Was feeding an animal
		if _target_tile.has_method("feed_animal"):
			_target_tile.feed_animal()
		select_box.play_placing()
		_clear()
	elif not is_carrying:
		# Check if target is a DroppedItem
		if _target_tile.has_method("pick_up"):
			_pick_up_dropped(_target_tile)
		elif _target_tile.has_method("is_harvestable") \
			and _target_tile.is_harvestable():
			finish_harvest()


# ── Internal ─────────────────────────────────────────────

func _pick_up_dropped(dropped: Node2D) -> void:
	var data: Dictionary = dropped.pick_up()
	var item = data.get("item_data") as ItemData
	if not item:
		return
	_target_tile = null
	_held_item = item

	if data.get("was_growing", false):
		# Growing crop / placeable item → hold as placeable
		_held_growth_phase = data.get("growth_phase", 0)
		_is_holding_product = false
		is_carrying = true
		select_box.set_size(Vector2i(1, 1))
		_update_carry_visual()
	else:
		# Finished item → hold as product (can sell)
		_is_holding_product = true
		is_carrying = true
		select_box.set_size(Vector2i(1, 1))
		_update_carry_visual()


func _update_carry_visual() -> void:
	if not _held_item:
		player_visual.set_carry_no_tool(false)
		player_visual.hide_held_item()
		return
		
	# Show item overhead if it's a product, fertilizer, or animal
	var ptype = _held_item.get_placeable_type()
	if _is_holding_product or ptype in [Placeable.Type.FERTILIZER, Placeable.Type.ANIMAL]:
		player_visual.set_carry_no_tool(true)
		player_visual.show_held_item(_held_item.icon)
	else:
		# Normal crops/seeds don't show overhead
		player_visual.set_carry_no_tool(false)
		player_visual.hide_held_item()


func _clear() -> void:
	is_carrying = false
	_held_item = null
	_held_growth_phase = 0
	_target_tile = null
	_is_holding_product = false
	player_visual.set_carry_no_tool(false)
	player_visual.hide_held_item()
