extends GoblinState

## Perform stealing animation. Cannot be interrupted.

var _steal_timer := 0.0


func enter() -> void:
	super()
	_steal_timer = 0.0
	goblin.velocity = Vector2.ZERO
	# Prevent health component/hurt anim from interrupting us
	goblin.interruptible = false
	goblin.visual.play_anim_locked("doing")


func exit() -> void:
	goblin.interruptible = true
	goblin.visual.unlock()


func physics_update(delta: float) -> void:
	goblin.velocity = Vector2.ZERO
	_steal_timer += delta

	# Ensure doing animation loops if it finishes early
	if not goblin.visual.is_locked():
		goblin.visual.play_anim_locked("doing")

	if _steal_timer >= goblin.steal_duration:
		if goblin.target_tile and goblin.loot.steal_crop_from_tile(goblin.target_tile):
			transition.emit("flee")
		else:
			transition.emit("roam")
