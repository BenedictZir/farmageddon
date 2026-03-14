extends Area2D

## A dropped item on the ground that the player can pick up.
## Created when a goblin dies while carrying loot.

@onready var sprite: Sprite2D = $Sprite2D

var item_data: Resource = null
var was_growing := false
var growth_phase := 0
var _icon: Texture2D = null


func setup(data: Dictionary) -> void:
	item_data = data.get("item_data")
	was_growing = data.get("was_growing", false)
	growth_phase = data.get("growth_phase", 0)
	_icon = data.get("icon")

	# Use icon if provided, otherwise use first phase texture
	if _icon:
		sprite.texture = _icon
	elif item_data is CropData and item_data.phase_textures.size() > 0:
		# Show the seed/growing sprite
		var phase = min(growth_phase, item_data.phase_textures.size() - 1)
		sprite.texture = item_data.phase_textures[phase]


func is_harvestable() -> bool:
	## Select box uses this to show the box on this item.
	return true


func pick_up() -> Dictionary:
	## Player picks this up. Returns data for player inventory.
	var result := {
		"item_data": item_data,
		"was_growing": was_growing,
		"growth_phase": growth_phase,
		"icon": _icon,
	}
	queue_free()
	return result
