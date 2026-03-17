extends State

## Carry stolen item and run to 

var _has_jumped := false

func enter() -> void:
	super()
	_has_jumped = false
	entity.movement_component.movement_speed = entity.walk_speed
	if entity.loot.use_no_tool:
		entity.show_held_item(entity.loot.stolen_icon)
	entity.flee_target = entity.get_nearest_edge()


func physics_update(_delta: float) -> void:
	var dir = (entity.flee_target - entity.global_position).normalized()
	
	var is_colliding := entity.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		_has_jumped = true
		entity.start_jump(0.8, 30.0)
	
	entity.movement_component.move(entity, dir)
	entity.update_flip(dir)

	if entity.get_collision_mask_value(1) == false:
		entity.visual.play_anim("jump")
	elif entity.loot.use_no_tool:
		entity.visual.play_anim("carry_no_tool")
	else:
		entity.visual.play_anim("carry")

	# Wait for VisibleOnScreenNotifier2D exit signal to free
	# (Handled in entity_ai via screen exited signal)
