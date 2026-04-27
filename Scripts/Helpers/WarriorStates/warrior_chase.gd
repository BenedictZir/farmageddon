extends State

## WarriorChase: Constantly move toward the enemy. If close enough, attack.

func physics_update(_delta: float) -> void:
	var target = entity._target_enemy
	if not entity._is_enemy_attackable(target):
		entity._target_enemy = null
		transition.emit("roam")
		return
	var enemy := target as Node2D

	var target_pos = enemy.global_position
	var to_enemy = target_pos - entity.global_position
	var dist = to_enemy.length()

	# Calculate flank positions (left and right of enemy)
	var flank_offset := Vector2(entity.attack_range, 0)
	var left_flank = target_pos - flank_offset
	var right_flank = target_pos + flank_offset

	# Choose the closest flank
	var dist_to_left = entity.global_position.distance_to(left_flank)
	var dist_to_right = entity.global_position.distance_to(right_flank)
	
	var chosen_flank = left_flank if dist_to_left < dist_to_right else right_flank
	var to_flank_dir = (chosen_flank - entity.global_position)
	
	# Check if we are in striking box (left or right of target)
	var is_aligned_y = abs(to_enemy.y) <= 8.0
	var is_aligned_x = abs(to_enemy.x) >= 10.0 and abs(to_enemy.x) <= entity.attack_range + 5.0
	var is_close_enough = is_aligned_y and is_aligned_x

	if not is_close_enough:
		# Chase to the flank
		var dir = to_flank_dir.normalized()
		entity.movement_component.move(entity, dir, true) # Run!
		entity.helper_visual.update_movement_anim(dir, true)
	else:
		# In range and aligned! Switch to attack
		transition.emit("attack")
