extends ItemData
class_name HelperData

@export var helper_scene: PackedScene

func get_placeable_type() -> int:
	return Placeable.Type.HELPER

func is_helper() -> bool:
	return true
