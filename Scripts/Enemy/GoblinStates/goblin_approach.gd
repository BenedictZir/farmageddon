extends GoblinState

## Approach a stealable crop or animal


func physics_update(_delta: float) -> void:
	if goblin.visual.is_locked():
		goblin.velocity = Vector2.ZERO
		goblin.move_and_slide()
		return

	if not goblin.target_tile or not goblin.is_tile_stealable(goblin.target_tile):
		goblin.target_tile = goblin.find_nearest_stealable()
		if not goblin.target_tile:
			transition.emit("roam")
			return

	var dir := (goblin.target_tile.global_position - goblin.global_position).normalized()
	goblin.movement_component.move(goblin, dir)
	goblin.visual.play_anim("run")
	goblin.update_flip(dir)

	var dist := goblin.global_position.distance_to(goblin.target_tile.global_position)
	if dist < 12.0:
		transition.emit("stealing")
