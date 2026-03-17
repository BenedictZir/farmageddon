extends ItemData
class_name CropData

## Data resource for a crop type.

@export var price := 10
@export var grow_time := 15.0
@export var phase_textures: Array[Texture2D] = []


func get_placeable_type() -> int:
	return Placeable.Type.CROP


func is_holdable_harvest() -> bool:
	return true


func get_drop_texture(growth_phase: int = 0) -> Texture2D:
	if phase_textures.size() > 0:
		var phase = min(growth_phase, phase_textures.size() - 1)
		return phase_textures[phase]
	return icon
