extends State
class_name BirdFlyInState

var fly_speed := 72.0

func enter() -> void:
	super()
	entity.visual.play_anim("fly")
	# Turn off collision so it is invincible while flying
	entity.set_collision_mask_value(4, false) # Player Hurtbox
	entity.set_collision_layer_value(3, false) # Enemy Hurtbox
	entity.collision_layer = 0
	entity.collision_mask = 0

func physics_update(delta: float) -> void:
	if not is_instance_valid(entity.target_tile) or entity.target_tile.placed_crop == null:
		# Retarget while flying; only flee if no planted crop remains.
		if entity.has_method("retarget_crop") and entity.retarget_crop():
			return
		transition.emit("FlyOut")
		return
		
	var target_pos: Vector2 = entity.target_tile.global_position
	var dir = entity.global_position.direction_to(target_pos)
	
	# Flip sprite (Bird sprite faces left by default, so invert dir)
	entity.update_flip(-dir)
	
	var dist = entity.global_position.distance_to(target_pos)
	if dist < 5.0:
		entity.global_position = target_pos
		transition.emit("Eat")
	else:
		entity.velocity = dir * fly_speed
		entity.move_and_slide()
