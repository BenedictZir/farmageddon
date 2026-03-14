extends Resource
class_name CropData

## Data resource for a crop type.

@export var crop_name := ""
@export var price := 10
@export var sell_price := 30
@export var grow_time := 15.0

@export var phase_textures: Array[Texture2D] = []
@export var icon: Texture2D
@export var placeable_type: Placeable.Type = Placeable.Type.CROP
