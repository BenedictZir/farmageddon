extends Node
class_name GoblinLoot

## Tracks what a goblin has stolen. Attached as child of goblin.

## The stolen resource data (CropData, etc.)
var stolen_data: Resource = null

## For growing crops: track the interrupted phase so it can resume
var was_growing := false
var growth_phase := 0

## The tile the crop was stolen from (to restore if needed)
var source_tile: Node2D = null

## Icon for the stolen item
var stolen_icon: Texture2D = null

## Whether the stolen item should use carry_no_tool
var use_no_tool := false


func steal_crop_from_tile(tile: Node2D) -> bool:
	## Steal the crop from a PlantableTile. Returns true if successful.
	if not tile or not tile.get("occupied") or not tile.get("placed_crop"):
		return false

	var crop = tile.placed_crop
	var data: CropData = crop.crop_data
	if not data:
		return false

	source_tile = tile

	if crop.fully_grown:
		# Harvestable crop → carry_no_tool + show icon
		stolen_data = data
		stolen_icon = data.icon
		use_no_tool = true
		was_growing = false
	else:
		# Growing crop → carry (with tool/box) + save phase
		stolen_data = data
		stolen_icon = null
		use_no_tool = false
		was_growing = true
		growth_phase = crop.growth_phase

	# Remove crop from tile
	crop.queue_free()
	tile.placed_crop = null
	tile.occupied = false
	return true


func has_loot() -> bool:
	return stolen_data != null


func get_drop_data() -> Dictionary:
	## Returns data needed to create a DroppedItem.
	return {
		"item_data": stolen_data,
		"icon": stolen_icon,
		"was_growing": was_growing,
		"growth_phase": growth_phase,
	}
