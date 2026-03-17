extends State

## Approach a stealable crop or animal


func physics_update(_delta: float) -> void:
	if entity.visual.is_locked():
		entity.velocity = Vector2.ZERO
		entity.move_and_slide()
		return

	if not entity.target_tile or not entity.is_tile_stealable(entity.target_tile):
		entity.target_tile = entity.find_nearest_stealable()
		if not entity.target_tile:
			transition.emit("roam")
			return

	var dir = (entity.target_tile.global_position - entity.global_position).normalized()
	entity.movement_component.move(entity, dir)
	entity.visual.play_anim("run")
	entity.update_flip(dir)

	var dist := entity.global_position.distance_to(entity.target_tile.global_position)
	if dist < 12.0:
		transition.emit("stealing")
