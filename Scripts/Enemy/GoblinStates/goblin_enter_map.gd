extends State

## Initial state: Head toward map center before wandering


func physics_update(_delta: float) -> void:
	var center := Vector2.ZERO
	var dir := (center - entity.global_position).normalized()
	
	var is_colliding := entity.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		_has_jumped = true
		entity.start_jump(0.8, 30.0)

	entity.movement_component.move(entity, dir)
	
	if entity.get_collision_mask_value(1) == false:
		entity.visual.play_anim("jump")
	else:
		entity.visual.play_anim("run")

	entity.update_flip(dir)
	
	if not _has_jumped:
		return
	# Check for objectives while heading to center
	var tile = entity.find_nearest_stealable()
	if tile:
		entity.target_tile = tile
		transition.emit("approach")
		return

	var player := PlayerRef.instance
	if player and not player.is_knocked:
		var dist := entity.global_position.distance_to(player.global_position)
		if dist < entity.player_detect_range:
			transition.emit("chase")
			return

	# Reached center? Start wandering
	if entity.global_position.distance_to(center) < 24.0:
		transition.emit("roam")

var _has_jumped := false

func enter() -> void:
	super()
	_has_jumped = false
