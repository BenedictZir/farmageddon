extends GoblinState

## Carry stolen item and run to 

var _has_jumped := false

func enter() -> void:
	super()
	_has_jumped = false
	goblin.movement_component.movement_speed = goblin.walk_speed
	if goblin.loot.use_no_tool:
		goblin.show_held_item(goblin.loot.stolen_icon)
	goblin.flee_target = goblin.get_nearest_edge()


func physics_update(_delta: float) -> void:
	var dir := (goblin.flee_target - goblin.global_position).normalized()
	
	var is_colliding := goblin.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		_has_jumped = true
		goblin.start_jump(0.8, 30.0)
	
	goblin.movement_component.move(goblin, dir)
	goblin.update_flip(dir)

	if goblin.get_collision_mask_value(1) == false:
		goblin.visual.play_anim("jump")
	elif goblin.loot.use_no_tool:
		goblin.visual.play_anim("carry_no_tool")
	else:
		goblin.visual.play_anim("carry")

	# Wait for VisibleOnScreenNotifier2D exit signal to free
	# (Handled in goblin_ai via screen exited signal)
