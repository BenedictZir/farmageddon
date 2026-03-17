extends ItemData
class_name FertilizerData

## Data resource for fertilizer items.

@export var price := 5


func get_placeable_type() -> int:
	return Placeable.Type.FERTILIZER
