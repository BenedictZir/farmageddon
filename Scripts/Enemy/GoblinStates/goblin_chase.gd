extends State

## Chase the player to attack. If a crop is found nearby, switches priority directly to ApproachSteal.


func physics_update(_delta: float) -> void:
	if entity.visual.is_locked():
		entity.velocity = Vector2.ZERO
		entity.move_and_slide()
		return
	var player := PlayerRef.instance
	if not player or player.is_knocked:
		transition.emit("roam")
		return

	var to_player := player.global_position - entity.global_position
	var dist := to_player.length()

	# If the player is very close (e.g., < 70px) they are the immediate threat, IGNORE crops!
	if dist > 70.0:
		var tile = entity.find_nearest_stealable()
		if tile:
			entity.target_tile = tile
			transition.emit("approach")
			return

	if dist > entity.player_detect_range * 1.5:
		transition.emit("roam")
		return

	# Calculate flank positions (left and right of player)
	var flank_offset := Vector2(entity.attack_range, 0)
	var left_flank := player.global_position - flank_offset
	var right_flank := player.global_position + flank_offset

	# Choose the closest flank
	var dist_to_left := entity.global_position.distance_to(left_flank)
	var dist_to_right := entity.global_position.distance_to(right_flank)
	
	var target_pos := left_flank if dist_to_left < dist_to_right else right_flank
	var to_target := target_pos - entity.global_position
	var dist_to_target := to_target.length()
	
	# Also check if we are in striking box (left or right of player)
	var is_aligned_y = abs(to_player.y) <= 8.0
	var is_aligned_x = abs(to_player.x) >= 10.0 and abs(to_player.x) <= entity.attack_stop_range + 5.0
	var is_close_enough = is_aligned_y and is_aligned_x

	if not is_close_enough:
		var move_dir := to_target.normalized()
		entity.update_flip(move_dir)
		entity.movement_component.move(entity, move_dir)
		entity.visual.play_anim("run")
	else:
		# Close enough AND aligned on Y/X — stop and attack
		var dir_to_player := to_player.normalized()
		entity.update_flip(dir_to_player)
		entity.velocity = Vector2.ZERO
		entity.move_and_slide()
		entity.visual.play_anim("idle")
		if entity.attack_cooldown <= 0:
			entity.do_attack()
