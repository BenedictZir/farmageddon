extends State

## Initial state: Head toward map center before wandering
var _has_jumped := false
var _jump_anim_finished = false

func physics_update(_delta: float) -> void:
	var center := Vector2.ZERO
	var dir := (center - entity.global_position).normalized()
	
	var is_colliding := entity.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		entity.start_jump(0.8, 30.0)
		_has_jumped = true
		await get_tree().create_timer(0.8).timeout
		_jump_anim_finished = true
	
	entity.movement_component.move(entity, dir)
	
	if entity.get_collision_mask_value(1) == false:
		entity.visual.play_anim("jump")
	else:
		entity.visual.play_anim("run")

	entity.update_flip(dir)
	
	if not _jump_anim_finished:
		return
		
	# Check for objectives while heading to center for goblin
	if entity is Goblin:
		var tile = entity.find_nearest_stealable()
		if tile:
			entity.target_tile = tile
			transition.emit("approach")
			return

	var targets = entity.get_combat_targets()

	# Find closest valid target
	if not targets.is_empty():
		var target = targets[0]
		var min_dist := entity.global_position.distance_to(target.global_position)
		for t in targets:
			var d = entity.global_position.distance_to(t.global_position)
			if d < min_dist:
				target = t
				min_dist = d
				
		if min_dist < entity.player_detect_range:
			transition.emit("chase")
			return

	# Reached center? Start wandering
	if entity.global_position.distance_to(center) < 24.0:
		transition.emit("roam")


func enter() -> void:
	super()
	_has_jumped = false
