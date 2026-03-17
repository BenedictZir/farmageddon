extends BirdState
class_name BirdFlyOutState

var fly_speed := 80.0
var fly_dir: Vector2

func enter() -> void:
	super()
	bird.visual.play_anim("fly")
	# Invincible again
	bird.collision_layer = 0
	bird.collision_mask = 0
	
	# Pick a random upward/sideways direction to flee
	var side = 1.0 if randf() > 0.5 else -1.0
	fly_dir = Vector2(side, -1.0).normalized()
	bird.update_flip(-fly_dir)
	
func physics_update(delta: float) -> void:
	bird.velocity = fly_dir * fly_speed
	bird.move_and_slide()
	
	# Destroy self when far offscreen (approx 300px away from roughly the center is safe enough)
	# A better check is if we are completely outside the viewport bounds + margin
	var vp_rect = bird.get_viewport_rect()
	var global_cam = bird.get_viewport().get_camera_2d()
	if global_cam:
		vp_rect.position = global_cam.get_screen_center_position() - (vp_rect.size / 2.0)
	
	vp_rect = vp_rect.grow(50) # Margin
	if not vp_rect.has_point(bird.global_position):
		bird.queue_free()
