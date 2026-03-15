extends Node
class_name PlayerInventory

## Manages what the player carries: seeds, harvested crops, items.
## Handles placing, harvesting, selling, and dropping.

var select_box: Node2D
var player_visual: Node2D
var player: CharacterBody2D

var is_carrying := false
var _held_item: Resource = null
var _held_growth_phase := 0
var _target_tile: Node2D = null
var _is_holding_harvest := false


func setup(p_player: CharacterBody2D, p_select_box: Node2D, p_visual: Node2D) -> void:
	player = p_player
	select_box = p_select_box
	player_visual = p_visual


# ── Public API ───────────────────────────────────────────

func interact() -> void:
	if is_carrying and _held_item:
		if _is_holding_harvest:
			_try_use_harvest()
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
		if (_held_item is CropData and _is_holding_harvest) or _held_item is ForageData:
			icon_tex = _held_item.icon
			
		item.setup({
			"item_data": _held_item,
			"was_growing": not _is_holding_harvest,
			"growth_phase": _held_growth_phase,
			"icon": icon_tex
		})
		_clear()


func hold_item(item: Resource, item_size := Vector2i(1, 1)) -> void:
	_held_item = item
	_held_growth_phase = 0
	_is_holding_harvest = false
	is_carrying = true
	select_box.set_size(item_size)
	player_visual.set_carry_no_tool(false)
	player_visual.hide_held_item()


func get_held_item() -> Resource:
	return _held_item


func is_holding_harvest() -> bool:
	return _is_holding_harvest


# ── Placing (seed → tile) ────────────────────────────────

func _try_place_item() -> void:
	var tile = select_box.current_target
	if not tile:
		return
	if tile.has_method("accepts_type") and _held_item.get("placeable_type") != null \
		and tile.accepts_type(_held_item.placeable_type):
		_target_tile = tile
		player.velocity = Vector2.ZERO
		player_visual.play_dig()
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
	if not _target_tile or not _target_tile.has_method("harvest_crop"):
		return
	var crop_data: CropData = _target_tile.harvest_crop()
	if not crop_data:
		return
	_target_tile = null
	_held_item = crop_data
	_is_holding_harvest = true
	is_carrying = true
	select_box.set_size(Vector2i(1, 1))
	player_visual.set_carry_no_tool(true)
	player_visual.show_held_item(crop_data.icon)


# ── Using harvest (sell / feed animal) ───────────────────

func _try_use_harvest() -> void:
	# Future: check select_box.current_target for feedable animal
	if _held_item is CropData or _held_item is ForageData:
		_sell_held_item()


func _sell_held_item() -> void:
	if _held_item.get("sell_price") != null:
		CurrencyManager.add_gold(_held_item.sell_price)
	select_box.play_placing()
	_clear()


# ── INTERACT animation callback (DIG/DOING) ─────────────

func on_interact_anim_finished() -> void:
	if not _target_tile:
		return
	if _held_item and not _is_holding_harvest:
		# Was placing a seed (or replanting dropped crop)
		if _held_item is CropData:
			if _held_growth_phase > 0 and _target_tile.has_method("plant_crop_at_phase"):
				_target_tile.plant_crop_at_phase(_held_item, _held_growth_phase)
			else:
				_target_tile.plant_crop(_held_item)
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
	var item = data.get("item_data")
	if not item:
		return
	_target_tile = null
	_held_item = item

	if data.get("was_growing", false):
		# Growing crop → hold as seed (can replant)
		_held_growth_phase = data.get("growth_phase", 0)
		_is_holding_harvest = false
		is_carrying = true
		select_box.set_size(Vector2i(1, 1))
		player_visual.set_carry_no_tool(false)
		player_visual.hide_held_item()
	else:
		# Harvested crop → hold as harvest (can sell)
		_is_holding_harvest = true
		is_carrying = true
		select_box.set_size(Vector2i(1, 1))
		player_visual.set_carry_no_tool(true)
		if item is CropData or item is ForageData:
			player_visual.show_held_item(item.icon)


func _clear() -> void:
	is_carrying = false
	_held_item = null
	_held_growth_phase = 0
	_target_tile = null
	_is_holding_harvest = false
	player_visual.set_carry_no_tool(false)
	player_visual.hide_held_item()
