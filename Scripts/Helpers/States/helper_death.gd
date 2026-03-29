extends State

## HelperDeath: terminal state, plays death hit effect and frees helper.

func enter() -> void:
	super()
	entity.velocity = Vector2.ZERO
	HitEffects.play_death(entity, func():
		if is_instance_valid(entity):
			entity.queue_free()
	)
