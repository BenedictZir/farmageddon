extends Area2D

## A tile where crops can be planted.

var occupied := false
var placed_crop: Node2D = null

const CROP_SCENE := preload("res://Scenes/Crops/crop.tscn")


func accepts_type(type: Placeable.Type) -> bool:
	return type == Placeable.Type.CROP and not occupied


func plant_crop(crop_data: CropData) -> void:
	if occupied:
		return
	occupied = true

	var crop_instance := CROP_SCENE.instantiate()
	add_child(crop_instance)
	crop_instance.position = Vector2.ZERO
	crop_instance.setup(crop_data)
	placed_crop = crop_instance
