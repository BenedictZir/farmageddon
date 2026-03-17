extends State

## Perform stealing animation. Cannot be interrupted.

var _steal_timer := 0.0


func enter() -> void:
	super()
	_steal_timer = 0.0
	entity.velocity = Vector2.ZERO
	# Prevent health component/hurt anim from interrupting us
	entity.interruptible = false
	entity.visual.play_anim_locked("doing")


func exit() -> void:
	entity.interruptible = true
	entity.visual.unlock()
	entity.set_interact_progress(0, false)


func physics_update(delta: float) -> void:
	entity.velocity = Vector2.ZERO
	_steal_timer += delta
	# Update bar
	entity.set_interact_progress(_steal_timer / entity.steal_duration, true)

	# Ensure doing animation loops if it finishes early
	if not entity.visual.is_locked():
		entity.visual.play_anim_locked("doing")

	if _steal_timer >= entity.steal_duration:
		if entity.target_tile and entity.loot.steal_crop_from_tile(entity.target_tile):
			transition.emit("flee")
		else:
			transition.emit("roam")
