extends BirdState
class_name BirdFlyInState

var fly_speed := 60.0

func enter() -> void:
	super()
	bird.visual.play_anim("fly")
	# Turn off collision so it is invincible while flying
	bird.set_collision_mask_value(4, false) # Player Hurtbox
	bird.set_collision_layer_value(3, false) # Enemy Hurtbox
	bird.collision_layer = 0
	bird.collision_mask = 0

func physics_update(delta: float) -> void:
	if not is_instance_valid(bird.target_tile) or bird.target_tile.placed_crop == null:
		# Crop was harvested or destroyed while we were flying to it
		transition.emit("FlyOut")
		return
		
	var target_pos: Vector2 = bird.target_tile.global_position
	var dir = bird.global_position.direction_to(target_pos)
	
	# Flip sprite (Bird sprite faces left by default, so invert dir)
	bird.update_flip(-dir)
	
	var dist = bird.global_position.distance_to(target_pos)
	if dist < 5.0:
		bird.global_position = target_pos
		transition.emit("Eat")
	else:
		bird.velocity = dir * fly_speed
		bird.move_and_slide()
