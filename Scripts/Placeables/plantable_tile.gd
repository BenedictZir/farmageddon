extends Area2D

## A tile where crops can be planted and harvested.

var occupied := false
var placed_crop: Node2D = null
const CROP_SCENE := preload("res://Scenes/Crops/crop.tscn")
@onready var fertilized_particle: CPUParticles2D = $FertilizedParticle


func _ready() -> void:
	add_to_group("plantable_tiles")


func accepts_type(type: Placeable.Type) -> bool:
	return (type == Placeable.Type.CROP and not occupied)  or (type == Placeable.Type.FERTILIZER and occupied)


func is_harvestable() -> bool:
	return occupied and placed_crop and placed_crop.fully_grown


func harvest_crop() -> CropData:
	fertilized_particle.emitting = false
	if not is_harvestable():
		return null
	var data: CropData = placed_crop.crop_data
	placed_crop.queue_free()
	placed_crop = null
	occupied = false
	return data


func plant_crop(crop_data: CropData) -> void:
	fertilized_particle.emitting = false
	if occupied:
		return
	occupied = true
	var crop_instance := CROP_SCENE.instantiate()
	add_child(crop_instance)
	crop_instance.position = Vector2.ZERO - Vector2(0, 2)
	crop_instance.setup(crop_data)
	placed_crop = crop_instance


func plant_crop_at_phase(crop_data: CropData, phase: int) -> void:
	## Plant a crop resuming from a specific growth phase.
	fertilized_particle.emitting = false
	plant_crop(crop_data)
	if placed_crop:
		placed_crop.growth_phase = phase
		placed_crop._update_sprite()

func fertilize():
	if placed_crop == null:
		return
	fertilized_particle.emitting = true
	placed_crop.fertilize()
