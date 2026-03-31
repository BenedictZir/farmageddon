extends Area2D

## A tile where crops can be planted and harvested.

var occupied := false
var placed_crop: Node2D = null
const CROP_SCENE := preload("res://Scenes/Crops/crop.tscn")
@onready var fertilized_particle: CPUParticles2D = $FertilizedParticle
@onready var tile_sprite: Sprite2D = $Tile
@onready var hole_sprite: Sprite2D = $Hole

@export var starts_locked := false

var _is_locked := false
var _tile_base_modulate := Color.WHITE
var _hole_base_modulate := Color.WHITE
var _visual_tween: Tween


func _ready() -> void:
	add_to_group("plantable_tiles")
	if tile_sprite:
		_tile_base_modulate = tile_sprite.modulate
	if hole_sprite:
		_hole_base_modulate = hole_sprite.modulate
	set_locked(starts_locked)


func accepts_type(type: Placeable.Type) -> bool:
	if _is_locked:
		return false
	return (type == Placeable.Type.CROP and not occupied)  or (type == Placeable.Type.FERTILIZER and occupied)


func is_harvestable() -> bool:
	if _is_locked:
		return false
	return occupied and placed_crop and placed_crop.fully_grown


func is_fertilizable() -> bool:
	if _is_locked:
		return false
	return occupied and placed_crop and not placed_crop.fully_grown and not placed_crop.fertilized


func get_fertilize_score() -> float:
	if not is_fertilizable():
		return -1.0
	# Score = price * 1000 - growth_phase
	# (Prioritizes highest value crop first, and among ties, the youngest crop)
	return (placed_crop.crop_data.sell_price * 1000.0) - placed_crop.growth_phase


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
	if occupied or _is_locked:
		return
	occupied = true
	var crop_instance := CROP_SCENE.instantiate()
	add_child(crop_instance)
	crop_instance.position = Vector2.ZERO - Vector2(0, 2)
	crop_instance.setup(crop_data)
	placed_crop = crop_instance


func plant_crop_at_phase(crop_data: CropData, phase: int) -> void:
	## Plant a crop resuming from a specific growth phase.
	if _is_locked:
		return
	fertilized_particle.emitting = false
	plant_crop(crop_data)
	if placed_crop:
		placed_crop.growth_phase = phase
		placed_crop._update_sprite()

func fertilize():
	if placed_crop == null or _is_locked:
		return
	fertilized_particle.emitting = true
	placed_crop.fertilize()


func is_locked() -> bool:
	return _is_locked


func set_locked(locked: bool, dark_tint := Color(0.45, 0.45, 0.45, 1.0), smooth_duration := 0.0) -> void:
	_is_locked = locked
	if _is_locked:
		fertilized_particle.emitting = false

	var tile_target := _tile_base_modulate * dark_tint if _is_locked else _tile_base_modulate
	var hole_target := _hole_base_modulate * dark_tint if _is_locked else _hole_base_modulate

	if _visual_tween and _visual_tween.is_running():
		_visual_tween.kill()

	if smooth_duration <= 0.0:
		if tile_sprite:
			tile_sprite.modulate = tile_target
		if hole_sprite:
			hole_sprite.modulate = hole_target
		return

	_visual_tween = create_tween()
	if tile_sprite:
		_visual_tween.tween_property(tile_sprite, "modulate", tile_target, smooth_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hole_sprite:
		_visual_tween.parallel().tween_property(hole_sprite, "modulate", hole_target, smooth_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
