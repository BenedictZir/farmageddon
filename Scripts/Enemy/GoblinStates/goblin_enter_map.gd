extends GoblinState

## Initial state: Head toward map center before wandering


func physics_update(_delta: float) -> void:
	var center := Vector2.ZERO
	var dir := (center - goblin.global_position).normalized()
	
	var is_colliding := goblin.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		_has_jumped = true
		goblin.start_jump(0.8, 30.0)

	goblin.movement_component.move(goblin, dir)
	
	if goblin.get_collision_mask_value(1) == false:
		goblin.visual.play_anim("jump")
	else:
		goblin.visual.play_anim("run")

	goblin.update_flip(dir)
	
	if not _has_jumped:
		return
	# Check for objectives while heading to center
	var tile := goblin.find_nearest_stealable()
	if tile:
		goblin.target_tile = tile
		transition.emit("approach")
		return

	var player := PlayerRef.instance
	if player and not player.is_knocked:
		var dist := goblin.global_position.distance_to(player.global_position)
		if dist < goblin.player_detect_range:
			transition.emit("chase")
			return

	# Reached center? Start wandering
	if goblin.global_position.distance_to(center) < 24.0:
		transition.emit("roam")

var _has_jumped := false

func enter() -> void:
	super()
	_has_jumped = false
