extends Resource
class_name ItemData

## Base class for all item data resources.
## All item types (crops, forages, fertilizer, etc.) should extend this.

@export var item_name: String = ""
@export var sell_price: int = 0
@export var icon: Texture2D


## Can this item be placed on a tile? Returns Placeable.Type or -1 if not placeable.
func get_placeable_type() -> int:
	return -1


## Is this item a "product" (harvested crop, egg, milk) that the player can sell?
func is_sellable_product() -> bool:
	return false


## Texture to show when this item is on the ground as a dropped item.
func get_drop_texture(growth_phase: int = 0) -> Texture2D:
	return icon


## Can this item be fed to animals?
func is_animal_feed() -> bool:
	return false
