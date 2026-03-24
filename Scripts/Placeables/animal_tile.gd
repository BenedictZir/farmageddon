extends Area2D

## A tile where animals can be placed and interacted with.
## Mirrors the plantable_tile pattern but for animals.

var occupied := false
var placed_animal: Node2D = null
const ANIMAL_SCENE := preload("res://Scenes/Animals/animal.tscn")


func _ready() -> void:
	add_to_group("animal_tiles")


func accepts_type(type: Placeable.Type) -> bool:
	return type == Placeable.Type.ANIMAL and not occupied


func is_feedable() -> bool:
	return occupied and placed_animal and placed_animal.is_hungry()


func is_harvestable() -> bool:
	return occupied and placed_animal and placed_animal.is_product_ready()


func feed_animal() -> void:
	if not is_feedable():
		return
	placed_animal.feed()


func harvest_product() -> ItemData:
	if not is_harvestable():
		return null
	return placed_animal.harvest_product()


func place_animal(animal_data: AnimalData) -> void:
	if occupied:
		return
	occupied = true
	var animal_instance := ANIMAL_SCENE.instantiate()
	add_child(animal_instance)
	animal_instance.position = Vector2.ZERO - Vector2(0, 2)
	animal_instance.setup(animal_data)
	placed_animal = animal_instance
