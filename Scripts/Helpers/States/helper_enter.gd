extends State

## HelperEnter: mirrors enemy enter_map.gd exactly.
## Walks toward center, jumps over fence, then transitions to idle/roam.

var _has_jumped := false
var _jump_anim_finished := false

func enter() -> void:
	super()
	_has_jumped = false
	_jump_anim_finished = false

func physics_update(_delta: float) -> void:
	var center := Vector2.ZERO
	var dir := (center - entity.global_position).normalized()
	
	var is_colliding := entity.get_slide_collision_count() > 0
	if is_colliding and not _has_jumped:
		entity.start_jump(0.8, 30.0)
		_has_jumped = true
		await get_tree().create_timer(0.8).timeout
		_jump_anim_finished = true
	
	entity.movement_component.move(entity, dir)
	
	if entity.get_collision_mask_value(1) == false:
		entity.helper_visual.play_state(HelperVisual.AnimState.JUMP)
	else:
		entity.helper_visual.update_movement_anim(dir)
	
	entity.helper_visual.update_direction(dir)
	
	if not _jump_anim_finished and _has_jumped:
		return
	
	# Transition immediately after jumping inside the map bounds
	if _has_jumped and _jump_anim_finished:
		if entity is WarriorHelper:
			transition.emit("roam")
		elif entity is FarmerHelper:
			transition.emit("idle")
