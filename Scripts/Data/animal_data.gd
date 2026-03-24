extends ItemData
class_name AnimalData

## Data resource for an animal type (chicken, cow, etc.)

@export var price: int = 100
@export var production_time: float = 30.0
@export var product_data: AnimalProductData

@export_group("Animation")
@export var sprite_sheet: Texture2D
@export var hframes: int = 1
@export var vframes: int = 1
@export var animation_speed: float = 5.0


func get_placeable_type() -> int:
	return Placeable.Type.ANIMAL
