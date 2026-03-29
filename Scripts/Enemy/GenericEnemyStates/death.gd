extends State

## EnemyDeath: terminal state, plays death hit effect and frees entity.

func enter() -> void:
	super()
	entity.velocity = Vector2.ZERO
	var visual = entity.get("visual")
	if visual and visual.has_method("unlock"):
		visual.unlock()
	HitEffects.play_death(entity, func():
		if is_instance_valid(entity):
			entity.queue_free()
	)
