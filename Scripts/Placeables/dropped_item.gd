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

	var target_tex: Texture2D = null

	# Use icon if provided, otherwise ask the item data for its drop texture
	if _icon:
		target_tex = _icon
	elif item_data is ItemData:
		target_tex = item_data.get_drop_texture(growth_phase)

	# Fix shader outline/cropping issues for atlas textures (like sprite strips)
	if target_tex:
		if target_tex is AtlasTexture:
			var img = target_tex.get_image()
			sprite.texture = ImageTexture.create_from_image(img)
		else:
			sprite.texture = target_tex

	# Implement specific visual behaviors
	if item_data is ForageData:	
		# 1. Disable outline and floating shader entirely for Forage items
		var material = sprite.material
		sprite.material = null
			
		# 2. Grow animation from the bottom center
		var tex_h = sprite.texture.get_height() if sprite.texture else 16.0
		sprite.scale = Vector2.ZERO
		sprite.position.y += tex_h / 2.0 # shift origin to bottom
		
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2.ONE, 0.6)
		tween.parallel().tween_property(sprite, "position:y", 0.0, 0.6)
		await tween.finished
		sprite.material = material
		sprite.material.set("shader_parameter/sine_amplitude", Vector2(0, 0))
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
